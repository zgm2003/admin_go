# Typed Config Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-field demo config with a typed config skeleton for app/http/mysql/redis/token.

**Architecture:** Config reads environment variables and produces typed structs only. It does not open DB/Redis connections. Bootstrap consumes typed config. Platform packages will later use these structs to create real clients.

**Tech Stack:** Go standard library, environment variables, duration/int parsing.

---

### Task 1: RED tests

**Files:**
- Create/Modify: `admin_back_go/internal/config/config_test.go`

- [x] Test defaults for app/http/mysql/redis/token config.
- [x] Test environment overrides.
- [x] Run `go test ./...` and verify failure before implementation.

### Task 2: Implement typed config

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] Add nested config structs.
- [x] Add string/int/duration env helpers with safe fallback.
- [x] Update bootstrap to use `cfg.HTTP.Addr` and `cfg.App.Env`.
- [x] Keep no external dependency for config.

### Task 3: Documentation

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/internal/platform/README.md`

- [x] Document config only describes resources; platform creates clients later.
- [x] Document current env names.

### Task 4: Verification

**Files:**
- All Go files.

- [x] Run `gofmt`.
- [x] Run `go test ./...`.
- [x] Smoke check server still starts with `HTTP_ADDR` override.
- [x] Confirm frontend stays clean.
