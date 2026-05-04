# Platform Database Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `internal/platform/database` as the only place that creates MySQL/GORM clients.

**Architecture:** Config describes MySQL settings; platform/database opens GORM and configures the underlying `database/sql` pool. Repositories will later receive the DB handle; platform/database must not contain RBAC or business rules.

**Tech Stack:** Go, GORM, gorm MySQL driver, database/sql pool settings.

---

### Task 1: RED tests

**Files:**
- Create: `admin_back_go/internal/platform/database/database_test.go`

- [x] Test empty DSN is rejected.
- [x] Test `Open` returns a client for a valid DSN without requiring a live MySQL server.
- [x] Test max open connection pool setting is applied.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement database platform boundary

**Files:**
- Create: `admin_back_go/internal/platform/database/database.go`

- [x] Implement `Client` with `Gorm` and `SQL` handles.
- [x] Implement `Open(config.MySQLConfig)`.
- [x] Use GORM MySQL driver with `SkipInitializeWithVersion` to avoid opening the network during construction.
- [x] Apply `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`.
- [x] Implement `Ping(ctx)` and `Close()`.

### Task 3: Documentation

**Files:**
- Modify: `admin_back_go/internal/platform/README.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] Document platform/database ownership.
- [x] Document repositories depend on database client, not config.
- [x] Document no business logic in platform.

### Task 4: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go mod tidy`.
- [x] Run `go test ./...`.
- [x] Smoke check `/health` still works.
- [x] Confirm frontend stays clean.
