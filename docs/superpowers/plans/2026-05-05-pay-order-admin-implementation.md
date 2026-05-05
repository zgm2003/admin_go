# Pay Order Admin Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the backend admin pay order page from legacy PHP POST APIs to Go REST endpoints under `/api/admin/v1/pay-orders` without touching user-side recharge/wallet runtime.

**Architecture:** Add `internal/module/payorder` using the existing Gin modular monolith shape: `route -> handler -> service -> repository -> model`. Read routes use `pay_recharge_list`; mutating close/remark routes use `pay_order_edit` and explicit operation log metadata. Frontend keeps the existing order view/composable but swaps only admin order APIs to Go REST.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, go-playground validator, Vue 3, TypeScript, Vitest.

---

## Tasks

- [ ] Add pay order enums, dict options, and validators.
- [ ] Add backend `payorder` DTO/model/repository/service/handler/routes with tests first.
- [ ] Register pay order service in bootstrap/server and route metadata.
- [ ] Add full-smoke probes for pay order init/status-count/list/detail/remark and conditional close.
- [ ] Update frontend `src/api/pay/order.ts` admin methods to Go REST while keeping wallet runtime legacy.
- [ ] Remove touched `any` in pay order view formatter.
- [ ] Update contracts, migration status, smoke matrix, and backend architecture docs.
- [ ] Run backend/frontend verification commands and report evidence.

## Verification Commands

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/payorder ./internal/module/paytransaction ./internal/module/permission ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay-order/usePayOrderPage.test.ts tests/shared/pay-order/pay-order-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/order.ts src/views/Main/pay/order/index.vue src/views/Main/pay/order/composables/usePayOrderPage.ts tests/shared/pay-order/usePayOrderPage.test.ts tests/shared/pay-order/pay-order-api.test.ts
```

Forbidden scans:

```powershell
rg "legacyRequest\.post<.*PayOrder|/api/admin/PayOrder" admin_front_ts/src/api/pay/order.ts admin_front_ts/src/views/Main/pay/order admin_front_ts/tests/shared/pay-order -n
rg "any|as any|Record<string, any>" admin_front_ts/src/api/pay/order.ts admin_front_ts/src/views/Main/pay/order admin_front_ts/tests/shared/pay-order -n
```
