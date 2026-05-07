# Pay Runtime Cron Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the first Alipay payment compensation cron slice from legacy PHP into Go: expired recharge order close and pending transaction sync.

**Architecture:** Reuse the existing Go cron registry path already proven by `notification_task_scheduler`. `cron_task` rows enqueue versioned Asynq tasks; payruntime handlers decode payloads and call service methods; service owns state transitions; repository owns DB; Alipay gateway owns SDK calls.

**Tech Stack:** Go 1.21+, Gin modular monolith, Gorm, Asynq wrapper, gocron registry, go-pay/gopay Alipay SDK.

---

## File map

- Modify `admin_back_go/internal/platform/payment/alipay/types.go`: add Query/Close request and result contracts to Gateway.
- Modify `admin_back_go/internal/platform/payment/alipay/gateway.go`: implement Query and Close using `TradeQuery` and `TradeClose`.
- Create `admin_back_go/internal/module/payruntime/jobs.go`: task constants, payload encode/decode, handler registration.
- Modify `admin_back_go/internal/module/payruntime/dto.go`: service inputs/results for cron jobs and repository scan rows.
- Modify `admin_back_go/internal/module/payruntime/service.go`: close-expired and pending-sync service methods.
- Modify `admin_back_go/internal/module/payruntime/repository.go`: scan expired orders, scan pending transactions, close order by id/status.
- Modify `admin_back_go/internal/module/payruntime/test_fakes_test.go`: fake repo/gateway support.
- Modify `admin_back_go/internal/module/payruntime/service_test.go`: cron service tests.
- Add `admin_back_go/internal/module/payruntime/jobs_test.go`: task payload/handler tests.
- Modify `admin_back_go/internal/module/crontask/registry.go`: add pay cron registry entries.
- Modify `admin_back_go/internal/module/crontask/*_test.go`: assert registered pay cron behavior.
- Modify `admin_back_go/internal/jobs/noop.go`: register payruntime handlers via dependencies.
- Modify `admin_back_go/internal/bootstrap/worker.go`: construct payruntime service for worker and pass to jobs.Register.
- Modify docs after tests are green.

## Tasks

### Task 1: Add failing tests for payruntime cron jobs

- [ ] Add job tests proving task type, payload defaults, and handlers call service.
- [ ] Add service tests proving close-expired and pending-sync state behavior.
- [ ] Run `go test ./internal/module/payruntime` and confirm failure because code does not exist.

### Task 2: Implement payruntime task contracts and service behavior

- [ ] Add `jobs.go`, DTOs, gateway interface methods, fake support.
- [ ] Implement service methods with no SDK call inside DB transaction.
- [ ] Run `go test ./internal/module/payruntime` and make it pass.

### Task 3: Implement Gorm repository and Alipay SDK wrapper

- [ ] Add repository scan/update methods.
- [ ] Add `Query` and `Close` wrapper around gopay Alipay.
- [ ] Run `go test ./internal/module/payruntime`.

### Task 4: Register cron entries and worker handlers

- [ ] Extend `crontask.NewDefaultRegistry()` with pay cron names.
- [ ] Extend `jobs.Dependencies` and `jobs.Register()` with payruntime job service.
- [ ] Build worker payruntime service in bootstrap.
- [ ] Run `go test ./internal/module/crontask ./internal/jobs ./internal/bootstrap`.

### Task 5: Update docs and verify

- [ ] Update current status, API contract, architecture, and smoke matrix if needed.
- [ ] Run `go test ./internal/module/payruntime ./internal/module/crontask ./internal/jobs ./internal/bootstrap`.
- [ ] Run `go test ./internal/module/paychannel ./internal/module/paytransaction ./internal/module/payorder ./internal/module/wallet ./internal/module/payruntime`.
- [ ] Run `git diff --check` in root and relevant subrepos.
