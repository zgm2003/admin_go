# Failure Troubleshooting Playbook

Date: 2026-06-08

This playbook is for narrowing runtime/doc/test failures without broad repo sweeps. Resolve evidence conflicts in AGENTS.md order: live runtime > smoke output > served API/assets > process config > persisted state > generated artifacts > source > comments.

## Fast triage matrix

| Symptom | First check | Likely owner | Do not do | Next command |
| --- | --- | --- | --- | --- |
| Backend unreachable | `/health`, Docker compose ps/logs | Docker/backend runtime | Do not edit frontend base URL first | `docker compose -f .docker\admin-go-backend\docker-compose.yml ps` |
| `/ready` fails DB/Redis | state containers and `MYSQL_DSN`/`REDIS_ADDR` | admin-go-state / env | Do not rebuild app image as a fix | `Invoke-WebRequest http://127.0.0.1:8080/ready` |
| Admin login/current-user fails | `/api/admin/v1/auth/*`, `/users/me`, session Redis | auth/user/permission | Do not revive `users/init` | `admin_back_go/scripts/basic-admin-smoke.ps1` |
| Canvas 401/403 | `/api/canvas/v1/users/me`, live `permissions` rows | auth/canvas + user/canvas + permission | Do not hardcode routes in Next | `admin_back_go/scripts/check-canvas-rbac.ps1` |
| Frontend API drift | generated frontend/backend drift | API contract owner | Do not label backend-only without source-only review | `scripts/export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-08` |
| Source-only route appears | source-only review artifact | route owner | Do not delete route just because no exact frontend call | `scripts/export-api-source-only-route-review.ps1 -OutputDate 2026-06-08` |
| Schema mismatch | live schema export and ownership map | DB/model owner | Do not trust migrations over live DB | `scripts/check-runtime-doc-facts.ps1 -LiveSchema` |
| Upload token fails | active upload settings + secretbox APP_SECRET | uploadconfig/uploadtoken | Do not copy encrypted blobs across APP_SECRET | `admin_back_go/scripts/full-admin-smoke.ps1` |
| Queue monitor blank | queue monitor source-only endpoints + Asynq Redis | queuemonitor/worker | Do not add frontend CRUD wrappers for iframe UI routes | check `/api/admin/v1/queue-monitor` |
| Realtime missing | websocket route + Redis publisher | realtime/notification/ai chat | Do not make WS own cancel; cancel is REST | check `/api/admin/v1/realtime/ws` route and logs |
| AI provider/model wrong | agent_id contract, provider/model source | ai/agent/provider | Do not accept client provider/model overrides in Canvas | run Canvas AI request tests |
| Docs checker fails | exact assertion line | docs/runtime fact owner | Do not loosen checker to pass stale docs | `scripts/check-runtime-doc-facts.ps1` |

## Debug loop

```text
1. Reproduce the smallest failing request/command.
2. Identify the owner capability from backend-capability-runbook or frontend-page-runtime-map.
3. Inspect service/repository/model before changing transport.
4. If data is involved, compare live schema artifact and current DB state.
5. Add or run the narrow guard test/smoke for the exact branch.
6. Refresh generated knowledge only after source/runtime facts changed.
```

## Bad fixes to reject

```text
user?.name || "" hiding bad data
API fallback to old users/init
frontend hardcoded routes outside backend router/buttonCodes
Canvas billing/balance checks in free-generation slice
Docker compose state and backend in one lifecycle
editing docs to match memory instead of generated artifacts/live DB
```
