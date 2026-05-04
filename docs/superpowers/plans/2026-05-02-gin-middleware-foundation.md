# Gin Middleware Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the first global Gin middleware skeleton for request tracing.

**Architecture:** Use Gin native middleware (`router.Use`) and keep middleware isolated under `internal/middleware`. Server owns global middleware ordering; modules own business routes.

**Tech Stack:** Go, Gin middleware, standard `httptest`.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/middleware/request_id_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [x] Test request ID generation.
- [x] Test incoming request ID preservation.
- [x] Test global router emits `X-Request-Id`.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement middleware

**Files:**
- Create: `admin_back_go/internal/middleware/request_id.go`
- Modify: `admin_back_go/internal/server/router.go`

- [x] Implement `RequestID()` Gin middleware.
- [x] Implement `GetRequestID()` helper.
- [x] Register middleware globally after recovery.

### Task 3: Document Gin usage

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Create: `admin_back_go/internal/middleware/README.md`

- [x] Document Gin as core framework.
- [x] Document middleware ownership and order.
- [x] Document that middleware is added only with tests.
