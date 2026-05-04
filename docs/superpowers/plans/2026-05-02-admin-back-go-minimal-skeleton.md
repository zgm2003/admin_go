# Admin Back Go Minimal Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the smallest runnable `admin_back_go` Gin backend skeleton.

**Architecture:** Keep the first Go service stupidly small: bootstrap config, create a Gin router, expose health and ping endpoints, and make tests prove the HTTP contract. No RBAC, no database, no Redis, no frontend changes in this phase.

**Tech Stack:** Go, Gin, standard `httptest`, standard `log/slog`.

---

### Task 1: Module setup and RED test

**Files:**
- Create: `admin_back_go/go.mod`
- Create: `admin_back_go/internal/server/router_test.go`

- [x] Initialize Go module as `admin_back_go`.
- [x] Write tests for `GET /health` and `GET /api/admin/v1/ping` before implementation.
- [x] Run `go test ./...` and verify it fails because `NewRouter` does not exist.

### Task 2: Minimal implementation

**Files:**
- Create: `admin_back_go/cmd/admin-api/main.go`
- Create: `admin_back_go/internal/bootstrap/app.go`
- Create: `admin_back_go/internal/config/config.go`
- Create: `admin_back_go/internal/server/router.go`
- Create: `admin_back_go/internal/response/response.go`
- Create: `admin_back_go/internal/version/version.go`

- [x] Implement config from environment with safe defaults.
- [x] Implement unified JSON response helpers.
- [x] Implement Gin router with health and ping endpoints.
- [x] Implement app bootstrap and main entry.

### Task 3: Verification

**Files:**
- Read and run all created Go files.

- [x] Run `gofmt`.
- [x] Run `go mod tidy`.
- [x] Run `go test ./...`.
- [x] Confirm no frontend files changed.
