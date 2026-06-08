# API Source-only Route Review Snapshot

Generated at: 2026-06-08 11:48:56 +08:00

Frontend/backend API drift source: `docs/knowledge/frontend-backend-api-drift-2026-06-08.md`

This artifact classifies backend admin/canvas routes that are not referenced by exact frontend API calls. It is a review aid, not runtime proof and not a deletion list.

## Summary

| Fact | Value |
| --- | --- |
| Frontend/backend API drift artifact | `docs/knowledge/frontend-backend-api-drift-2026-06-08.md` |
| Source-only routes reviewed | `19` |
| admin-queue-monitor-endpoint | `3` |
| frontend-parametric-helper-covered | `6` |
| retained-canvas-payment-wallet-domain | `6` |
| runtime-system-endpoint | `4` |
| Owner-decision-required routes | `0` |

## Owner-decision-required routes

| Surface | Capability | Method | Path | Route source | Evidence | Next action |
| --- | --- | --- | --- | --- | --- | --- |

## Full classification

| Category | Surface | Capability | Method | Path | Route source | Evidence | Next action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `admin-queue-monitor-endpoint` | `admin` | `queuemonitor` | `GET` | `/api/admin/v1/queue-monitor` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:18` | `admin_front_ts uses queue-monitor UI iframe/auth-cookie path; stats/failed and wildcard UI routes are backend runtime/asynqmon surfaces` | `keep as backend/admin tooling endpoint; do not require exact CRUD wrapper call` |
| `admin-queue-monitor-endpoint` | `admin` | `queuemonitor` | `ANY` | `/api/admin/v1/queue-monitor-ui/*path` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:21` | `admin_front_ts uses queue-monitor UI iframe/auth-cookie path; stats/failed and wildcard UI routes are backend runtime/asynqmon surfaces` | `keep as backend/admin tooling endpoint; do not require exact CRUD wrapper call` |
| `admin-queue-monitor-endpoint` | `admin` | `queuemonitor` | `GET` | `/api/admin/v1/queue-monitor/failed` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:19` | `admin_front_ts uses queue-monitor UI iframe/auth-cookie path; stats/failed and wildcard UI routes are backend runtime/asynqmon surfaces` | `keep as backend/admin tooling endpoint; do not require exact CRUD wrapper call` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-drivers` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:19` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-drivers/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:18` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-rules` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:27` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-rules/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:26` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-settings` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:36` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `frontend-parametric-helper-covered` | `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-settings/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:35` | `admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site` | `keep excluded from exact matching unless frontend inventory learns interprocedural base resolution` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment` | `GET` | `/api/canvas/v1/payment/recharges` | `admin_back_go/internal/module/payment/transport/canvas/route.go:15` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment` | `POST` | `/api/canvas/v1/payment/recharges` | `admin_back_go/internal/module/payment/transport/canvas/route.go:16` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment` | `POST` | `/api/canvas/v1/payment/recharges/:id/pay` | `admin_back_go/internal/module/payment/transport/canvas/route.go:17` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment` | `GET` | `/api/canvas/v1/payment/recharges/page-init` | `admin_back_go/internal/module/payment/transport/canvas/route.go:14` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment/wallet` | `GET` | `/api/canvas/v1/wallet/summary` | `admin_back_go/internal/module/payment/wallet/transport/canvas/route.go:14` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `retained-canvas-payment-wallet-domain` | `canvas` | `payment/wallet` | `GET` | `/api/canvas/v1/wallet/transactions` | `admin_back_go/internal/module/payment/wallet/transport/canvas/route.go:15` | `retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge` | `keep retained-domain wording; do not reintroduce billing UI without product decision` |
| `runtime-system-endpoint` | `admin` | `realtime` | `GET` | `/api/admin/v1/realtime/ws` | `admin_back_go/internal/module/realtime/transport/admin/route.go:20` | `health/ready/ping/websocket endpoint; exact frontend HTTP API call is not required` | `keep documented as runtime/backend-only unless served behavior changes` |
| `runtime-system-endpoint` | `admin` | `system` | `GET` | `/api/admin/v1/ping` | `admin_back_go/internal/module/system/transport/admin/route.go:17` | `health/ready/ping/websocket endpoint; exact frontend HTTP API call is not required` | `keep documented as runtime/backend-only unless served behavior changes` |
| `runtime-system-endpoint` | `admin` | `system` | `GET` | `/health` | `admin_back_go/internal/module/system/transport/admin/route.go:13` | `health/ready/ping/websocket endpoint; exact frontend HTTP API call is not required` | `keep documented as runtime/backend-only unless served behavior changes` |
| `runtime-system-endpoint` | `admin` | `system` | `GET` | `/ready` | `admin_back_go/internal/module/system/transport/admin/route.go:14` | `health/ready/ping/websocket endpoint; exact frontend HTTP API call is not required` | `keep documented as runtime/backend-only unless served behavior changes` |

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
