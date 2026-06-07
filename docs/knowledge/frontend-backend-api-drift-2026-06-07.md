# Frontend Backend API Drift Snapshot

Generated at: 2026-06-08 06:03:46 +08:00

Backend route inventory: `docs/knowledge/backend-route-inventory-2026-06-07.md`
Frontend API inventory: `docs/knowledge/frontend-api-inventory-2026-06-07.md`

This artifact compares frontend source API calls with backend route source inventory. It is not served-route smoke, not browser runtime proof, and not an OpenAPI schema. Dynamic route segments are normalized to `:param`; backend `ANY` routes can satisfy exact frontend methods. Parametric helpers, wrapper internals, blob/download calls, external HTTP calls, and Next proxy calls stay outside exact route matching.

## Summary

| Fact | Value |
| --- | --- |
| Backend route inventory artifact | `docs/knowledge/backend-route-inventory-2026-06-07.md` |
| Frontend API inventory artifact | `docs/knowledge/frontend-api-inventory-2026-06-07.md` |
| Backend route registrations available | `298` |
| Active backend admin/canvas routes | `288` |
| Frontend exact backend API calls compared | `277` |
| Distinct frontend exact method/path keys | `269` |
| frontend-route-match | `277` |
| frontend-method-mismatch | `0` |
| frontend-no-backend-route | `0` |
| Backend admin/canvas routes not referenced by exact frontend calls | `19` |
| Frontend parametric backend helper calls excluded from exact matching | `2` |
| Frontend external HTTP calls excluded from exact matching | `3` |
| Frontend blob/download calls excluded from exact matching | `4` |
| Frontend wrapper/proxy calls excluded from exact matching | `7` |
| Frontend inventory unresolved expressions | `0` |

## Frontend exact calls without backend route match

This table must stay empty for current exact frontend backend calls. If it gains rows, fix source or contract evidence instead of hiding it behind defaults.

| Class | Project | Source | Client | Method | Path | Method candidates | Raw URL expression |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Backend admin/canvas routes not referenced by exact frontend calls

These are backend source routes with no exact frontend method/path call in the current source inventory. This is not automatically a bug: runtime endpoints, retained backend domains, websocket paths, queue monitor routes, and parametric frontend helpers are deliberately separated.

| Surface | Capability | Method | Path | Route source | Note |
| --- | --- | --- | --- | --- | --- |
| `admin` | `queuemonitor` | `GET` | `/api/admin/v1/queue-monitor` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:18` | `queue monitor runtime/admin UI endpoint` |
| `admin` | `queuemonitor` | `ANY` | `/api/admin/v1/queue-monitor-ui/*path` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:21` | `queue monitor runtime/admin UI endpoint` |
| `admin` | `queuemonitor` | `GET` | `/api/admin/v1/queue-monitor/failed` | `admin_back_go/internal/module/queuemonitor/transport/admin/route.go:19` | `queue monitor runtime/admin UI endpoint` |
| `admin` | `realtime` | `GET` | `/api/admin/v1/realtime/ws` | `admin_back_go/internal/module/realtime/transport/admin/route.go:20` | `runtime/system endpoint` |
| `admin` | `system` | `GET` | `/api/admin/v1/ping` | `admin_back_go/internal/module/system/transport/admin/route.go:17` | `runtime/system endpoint` |
| `admin` | `system` | `GET` | `/health` | `admin_back_go/internal/module/system/transport/admin/route.go:13` | `runtime/system endpoint` |
| `admin` | `system` | `GET` | `/ready` | `admin_back_go/internal/module/system/transport/admin/route.go:14` | `runtime/system endpoint` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-drivers` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:19` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-drivers/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:18` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-rules` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:27` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-rules/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:26` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-settings` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:36` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `admin` | `uploadconfig` | `DELETE` | `/api/admin/v1/upload-settings/:id` | `admin_back_go/internal/module/uploadconfig/transport/admin/route.go:35` | `covered by Admin uploadConfig parametric delete helper in source inventory` |
| `canvas` | `payment` | `GET` | `/api/canvas/v1/payment/recharges` | `admin_back_go/internal/module/payment/transport/canvas/route.go:15` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |
| `canvas` | `payment` | `POST` | `/api/canvas/v1/payment/recharges` | `admin_back_go/internal/module/payment/transport/canvas/route.go:16` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |
| `canvas` | `payment` | `POST` | `/api/canvas/v1/payment/recharges/:id/pay` | `admin_back_go/internal/module/payment/transport/canvas/route.go:17` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |
| `canvas` | `payment` | `GET` | `/api/canvas/v1/payment/recharges/page-init` | `admin_back_go/internal/module/payment/transport/canvas/route.go:14` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |
| `canvas` | `payment/wallet` | `GET` | `/api/canvas/v1/wallet/summary` | `admin_back_go/internal/module/payment/wallet/transport/canvas/route.go:14` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |
| `canvas` | `payment/wallet` | `GET` | `/api/canvas/v1/wallet/transactions` | `admin_back_go/internal/module/payment/wallet/transport/canvas/route.go:15` | `retained Canvas payment/wallet base domain, not active free-generation UI dependency` |

## Frontend non-exact API rows excluded from route matching

| Classification | Count |
| --- | ---: |
| `backend-admin-parametric` | `2` |
| `blob/download` | `4` |
| `external` | `3` |
| `next-proxy` | `1` |
| `wrapper-internal` | `6` |

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
