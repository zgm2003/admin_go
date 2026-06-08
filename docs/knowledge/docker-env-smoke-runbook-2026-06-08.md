# Docker Env Smoke Runbook

Date: 2026-06-08

This runbook expands deployment knowledge into the exact local/prod Docker-first operating map. It does not replace `docs/deployment/docker-first-backend.md`, `docs/deployment/docker-first-state.md`, or smoke scripts.

## Runtime topology

| Layer | Current owner | Local evidence | Production rule |
| --- | --- | --- | --- |
| State | `admin-go-state` | `admin-go-state-mysql` on `127.0.0.1:3307`; `admin-go-state-redis` on `127.0.0.1:6380` | State lifecycle is independent; never `down -v` as part of backend release |
| Backend app | `admin-go-backend` | `.docker/admin-go-backend/docker-compose.yml` runs `admin-api` + `admin-worker` | One image, two processes; worker exposes no public port |
| HTTP | `admin-api` | `127.0.0.1:8080` Docker-first health endpoint | Nginx/Baota reverse proxy owns public TLS |
| Queue/scheduler | `admin-worker` | Redis DB selected by `QUEUE_REDIS_DB` | Rebuild/restart with app, not with state |
| Logs | runtime volume | `.docker/admin-go-backend/runtime/logs` | mount `/app/runtime`, tail through backend log API only for whitelisted `.log` files |

## Local commands

```powershell
cd E:\admin_go
docker compose -f .docker\admin-go-backend\docker-compose.yml up -d --build
docker compose -f .docker\admin-go-backend\docker-compose.yml ps
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/health
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/ready
```

## Smoke commands

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-canvas-rbac.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1
```

## Env ownership

| Env / config | Owner | Rule |
| --- | --- | --- |
| `MYSQL_DSN` | backend runtime env | points to state MySQL; schema truth still comes from live snapshot |
| `REDIS_ADDR` / `REDIS_PASSWORD` | backend runtime env | Redis must not be public; queue/realtime/session use configured Redis |
| `APP_SECRET` | all backend nodes | must be identical; changing it breaks secretbox-encrypted blobs |
| `CORS_ALLOW_ORIGINS` | API edge policy | frontend origin list; do not use wildcard in production |
| `QUEUE_ENABLED`, `QUEUE_REDIS_DB`, `QUEUE_CONCURRENCY` | worker runtime | lane names/retries/timeouts are Go defaults, not env |
| `REALTIME_ENABLED`, `REALTIME_PUBLISHER` | realtime runtime | channel/heartbeat/buffer are Go defaults unless source changes |
| upload driver settings | DB/admin UI | provider, bucket, region, keys, token TTL are DB-owned, not Docker env |

## Release safety

```text
1. Pull/rebuild backend only under admin-go-backend.
2. Do not restart or recreate admin-go-state unless explicitly doing DB/Redis maintenance.
3. Check /health and /ready before frontend smoke.
4. Run targeted smoke for touched capability.
5. Refresh docs/knowledge artifacts only when source/schema/API ownership changed.
```
