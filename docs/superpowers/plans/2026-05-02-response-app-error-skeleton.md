# Response App Error Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a minimal app error model and unified JSON error response for future auth/RBAC middleware.

**Architecture:** Domain/service code returns `apperror.Error` without depending on Gin. HTTP handlers and middleware map app errors to `code/data/msg` JSON through `response`. This keeps service logic free of transport details and preserves the legacy response shape.

**Tech Stack:** Go, Gin, standard `httptest`.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/apperror/error_test.go`
- Create: `admin_back_go/internal/response/response_test.go`

- [x] Test predefined app errors keep legacy-compatible codes: 100/401/403/404/500.
- [x] Test response error writes `{code,data,msg}` and HTTP status.
- [x] Test response abort writes error response and stops Gin chain.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement app error and response mapping

**Files:**
- Create: `admin_back_go/internal/apperror/error.go`
- Modify: `admin_back_go/internal/response/response.go`

- [x] Implement app error type with code, HTTP status, message, and unwrap support.
- [x] Implement constructors for bad request, unauthorized, forbidden, not found, internal.
- [x] Implement `response.Error` and `response.Abort`.
- [x] Keep `response.OK` response shape unchanged.

### Task 3: Documentation

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/internal/module/README.md`

- [x] Document service returns app errors, handler maps via response.
- [x] Document middleware uses `response.Abort` for 401/403.

### Task 4: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go test ./...`.
- [x] Smoke check `/health` still returns success shape.
- [x] Confirm frontend stays clean.
