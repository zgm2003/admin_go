# Payment Config Naming Canonicalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Canonicalize the payment config slice around `payment_configs` while keeping V1 Alipay-only and config-only.

**Architecture:** The product/API/menu concept is `payment config`; provider-specific behavior is selected by `provider=alipay`, not by baking Alipay into table names. The first version stores only fields used by the current Alipay certificate-mode config page and local config test; no WeChat fields, no refund/order/notify runtime, no generic `config_json` dumping ground.

**Tech Stack:** Go + Gin + GORM + MySQL migrations; Vue 3 + Pinia + Vue Router + typed API client; repo-native Go tests, Vitest, vue-tsc, contract check.

---

### Task 1: Lock naming contract with tests

**Files:**
- Modify: `admin_back_go/internal/module/payment/config_service_test.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/mapper_test.go`
- Modify: `admin_front_ts/tests/shared/payment/payment-config-api.test.ts`
- Modify: `admin_front_ts/tests/shared/payment/payment-config-page.test.ts`

- [x] Add/adjust tests that expect the backend model table to be `payment_configs`, not `payment_alipay_configs`.
- [x] Add/adjust tests that expect provider to be present and limited to `alipay` in this slice.
- [x] Add/adjust frontend tests to require `payment_config_del` instead of `payment_config_delete`.
- [x] Run focused tests and confirm they fail for the old naming before implementation.

### Task 2: Backend schema/model/repository canonicalization

**Files:**
- Modify: `admin_back_go/internal/module/payment/model.go`
- Modify: `admin_back_go/internal/module/payment/*.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/*.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/database/migrations/20260515_payment_config_rebuild_v1.sql`
- Modify: `admin_back_go/database/migrations/20260515_payment_config_only_cleanup.sql`

- [x] Rename runtime table contract to `payment_configs`.
- [x] Rename Go type from provider-specific `AlipayConfig` to payment-domain `Config` where it represents DB rows.
- [x] Add/use `provider` with current allowed value `alipay`; use it in service validation and gateway test dispatch.
- [x] Rename generic credential columns: `app_private_key_enc` -> `private_key_enc`, `app_private_key_hint` -> `private_key_hint`, `alipay_cert_path` -> `platform_cert_path`, `alipay_root_cert_path` -> `root_cert_path`.
- [x] Keep UI/API compatibility aliases only where deliberately needed; do not leak encrypted private key.
- [x] Change permission route metadata from `payment_config_delete` to `payment_config_del`.
- [x] Clear DIR permission code for `menu.payment`.

### Task 3: Frontend API/page canonicalization

**Files:**
- Modify: `admin_front_ts/src/api/payment/config.ts`
- Modify: `admin_front_ts/src/views/Main/payment/config/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/config/components/PaymentConfigForm.vue`
- Modify: `admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts`

- [x] Expose/display `provider` as `alipay` in typed API data.
- [x] Keep the page at `/payment/config` and component at `payment/config`.
- [x] Replace all button checks from `payment_config_delete` to `payment_config_del`.
- [x] Keep certificate labels provider-aware enough for Alipay now, without adding WeChat-only fields.

### Task 4: Docs and verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/superpowers/plans/2026-05-15-payment-config-rebuild-v1.md`
- Modify: `docs/superpowers/specs/2026-05-15-payment-config-rebuild-v1-design.md`
- Modify as needed: `admin_back_go/docs/architecture.md`

- [x] Sync docs to `payment_configs`, `provider=alipay`, and `payment_config_del`.
- [x] Run focused Go tests for config/payment/platform/bootstrap/server modules.
- [x] Run focused frontend Vitest and `vue-tsc`.
- [x] Run contract checker.
- [x] Report exact validation commands and results.


## Execution Notes

- 2026-05-15: Applied to code, docs, and live local DB.
- Live DB now has active table `payment_configs`; `payment_alipay_configs` was copied then dropped. Backup tables: `backup_payment_configs_before_20260515`, `permissions_backup_payment_20260515`, `role_permissions_backup_payment_20260515`.
- Current provider contract remains Alipay-only: `provider=alipay` is validated, displayed, list-filterable, and passed into local config test dispatch.
