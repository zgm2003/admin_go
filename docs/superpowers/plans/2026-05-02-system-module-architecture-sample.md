# System Module Architecture Sample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor health and ping into the first real module sample using `route -> handler -> service`.

**Architecture:** Keep `server` responsible only for Gin engine and module registration. Put system HTTP behavior in `internal/module/system`. No repository/model because system has no database.

**Tech Stack:** Go, Gin, standard testing, httptest.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/module/system/service_test.go`

- [x] Test `Service.Health()` returns service/status/version.
- [x] Test `Service.Ping()` returns message pong.
- [x] Run `go test ./...` and verify failure because system service does not exist.

### Task 2: Implement system module

**Files:**
- Create: `admin_back_go/internal/module/system/dto.go`
- Create: `admin_back_go/internal/module/system/service.go`
- Create: `admin_back_go/internal/module/system/handler.go`
- Create: `admin_back_go/internal/module/system/route.go`
- Modify: `admin_back_go/internal/server/router.go`

- [x] Implement DTO structs.
- [x] Implement service with no Gin dependency.
- [x] Implement handler that only calls service and response helper.
- [x] Implement route registration for `/health` and `/api/admin/v1/ping`.
- [x] Make server register the system module.

### Task 3: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go test ./...`.
- [x] Smoke check `/health` and `/api/admin/v1/ping`.
- [x] Confirm no frontend changes.
