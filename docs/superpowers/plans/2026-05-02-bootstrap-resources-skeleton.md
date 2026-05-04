# Bootstrap Resources Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bootstrap resource container that owns platform client lifecycle.

**Architecture:** `internal/bootstrap` wires config to platform clients. Resources can be absent when config is empty so the HTTP skeleton can still run. Business modules do not create DB/Redis clients directly.

**Tech Stack:** Go standard library, existing platform/database, existing platform/redisclient.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/bootstrap/resources_test.go`

- [x] Test empty MySQL DSN does not fail startup and leaves DB nil.
- [x] Test empty Redis addr leaves Redis nil.
- [x] Test valid config creates DB and Redis clients without requiring live services.
- [x] Test Close is safe on nil resources.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement resources lifecycle

**Files:**
- Create: `admin_back_go/internal/bootstrap/resources.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] Implement `Resources` with DB and Redis fields.
- [x] Implement `NewResources(config.Config)`.
- [x] Implement `Close()`.
- [x] Make `App` own resources and close them during shutdown.

### Task 3: Documentation

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/internal/platform/README.md`

- [x] Document bootstrap owns lifecycle.
- [x] Document platform creates clients and modules consume injected resources later.

### Task 4: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go test ./...`.
- [x] Smoke check `/health` still works with empty MySQL DSN.
- [x] Confirm frontend stays clean.
