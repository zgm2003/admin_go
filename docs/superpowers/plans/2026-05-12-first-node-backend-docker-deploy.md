# First Node Backend Docker Deploy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the minimal Docker deployment assets for the first Tencent Cloud/Baota node where frontend static files and the first backend API/worker pair live together.

**Architecture:** Build one Go image from `admin_back_go`, then run two processes from it: `admin-api` exposes `127.0.0.1:8080`, while `admin-worker` consumes queue and scheduler tasks without opening a public port. MySQL and Redis remain external state services so later backend nodes can join without changing frontend URLs.

**Tech Stack:** Go, Gin, Docker multi-stage build, Docker Compose, Baota/OpenResty reverse proxy.

---

### Task 1: Backend image and first-node compose template

**Files:**
- Create: `admin_back_go/Dockerfile`
- Create: `admin_back_go/.dockerignore`
- Create: `admin_back_go/deploy/first-node/docker-compose.yml`
- Create: `admin_back_go/deploy/first-node/admin-go.env.example`

- [x] **Step 1: Build a single image containing both backend binaries**

Use a multi-stage Dockerfile that compiles:

```bash
go build -ldflags="-s -w" -o /out/admin-api ./cmd/admin-api
go build -ldflags="-s -w" -o /out/admin-worker ./cmd/admin-worker
```

Expected: final image contains `/app/admin-api` and `/app/admin-worker`.

- [x] **Step 2: Keep runtime data out of the image**

Mount these host directories into both containers:

```text
/www/docker/admin-go/runtime -> /app/runtime
/www/docker/admin-go/exports -> /app/exports
```

Expected: logs, payment certs, and export files survive container rebuilds.

- [x] **Step 3: Expose only the API process locally**

Compose maps:

```text
${ADMIN_API_HOST_BIND:-127.0.0.1}:${ADMIN_API_HOST_PORT:-8080} -> admin-api:8080
```

Expected: first node defaults to local-only `127.0.0.1`; second backend node can bind `0.0.0.0` or its private IP and rely on security group/firewall to allow only the edge node.

### Task 2: First-node Baota reverse proxy runbook

**Files:**
- Create: `admin_back_go/deploy/first-node/nginx-www.zgm2003.cn.conf.example`
- Create: `docs/deployment/first-node-baota-docker.md`

- [x] **Step 1: Document the server directory layout**

Use:

```text
/www/project/admin_back_go
/www/docker/admin-go
/www/docker/admin-go/runtime
/www/docker/admin-go/exports
```

Expected: deployment paths match the compose template.

- [x] **Step 2: Document the Nginx reverse proxy**

Proxy `www.zgm2003.cn` to:

```text
http://127.0.0.1:8080
```

Expected: REST and WebSocket traffic preserve `Upgrade`, `Host`, forwarded IP, and request ID headers.

### Task 3: Verification

**Files:**
- Verify: `admin_back_go/Dockerfile`
- Verify: `admin_back_go/deploy/first-node/docker-compose.yml`
- Verify: `admin_back_go/deploy/first-node/admin-go.env.example`
- Verify: `docs/deployment/first-node-baota-docker.md`

- [x] **Step 1: Parse the compose file**

Run:

```bash
docker compose -f admin_back_go/deploy/first-node/docker-compose.yml --env-file admin_back_go/deploy/first-node/admin-go.env.example config
```

Expected: compose renders valid service definitions. Real secrets are not required for config rendering.

- [x] **Step 2: Build-check Go binaries locally**

Run:

```bash
go build ./cmd/admin-api ./cmd/admin-worker
```

Expected: both entrypoints compile.
