# Platform Redis Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `internal/platform/redis` as the only place that creates Redis clients.

**Architecture:** Config describes Redis settings; platform/redis creates go-redis clients and exposes Ping/Close. Token/session/RBAC cache semantics will live in modules/services later, not inside platform.

**Tech Stack:** Go, go-redis v9, context.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/platform/redisclient/redis_test.go`

- [x] Test `Open` maps config to go-redis options.
- [x] Test `Close` is safe on nil client.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement Redis platform boundary

**Files:**
- Create: `admin_back_go/internal/platform/redisclient/redis.go`

- [x] Implement `Client` with go-redis handle.
- [x] Implement `Open(config.RedisConfig)`.
- [x] Implement `Ping(ctx)` and `Close()`.
- [x] Do not encode token/RBAC key rules here.

### Task 3: Documentation

**Files:**
- Modify: `admin_back_go/internal/platform/README.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] Document Redis client ownership.
- [x] Document cache key ownership belongs to modules/services.

### Task 4: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go mod tidy`.
- [x] Run `go test ./...`.
- [x] Smoke check `/health` still works.
- [x] Confirm frontend stays clean.
