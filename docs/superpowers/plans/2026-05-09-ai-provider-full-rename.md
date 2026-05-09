# AI Provider Full Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the AI supplier domain from engine connection terminology to provider terminology across DB, backend, frontend, docs, smoke, and local MySQL.

**Architecture:** This is a destructive migration because the project is still in active rewrite and the old API/table names are misleading. The provider table becomes `ai_providers`; all runtime references use `provider_id`; REST and TypeScript contracts use `/ai-providers` and `AiProvider*` names. No compatibility route is retained.

**Tech Stack:** Go/Gin/GORM, MySQL 8, Vue 3/TypeScript/Vitest, PowerShell smoke scripts.

---

## File map

- Backend provider module: move `admin_back_go/internal/module/aiengine/*` to `admin_back_go/internal/module/aiprovider/*` and rename package/type/API wording.
- Backend consumers: update `aiapp`, `aiknowledgemap`, `aitoolmap`, `aichat`, `airun`, `server`, `bootstrap` from engine connection to provider names.
- DB migrations: add `20260509_rename_ai_engine_connections_to_providers.sql`; update rebuild/rollback/openai cleanup migrations to use new table/column names.
- Frontend API: move `admin_front_ts/src/api/ai/engineConnections.ts` to `admin_front_ts/src/api/ai/providers.ts`.
- Frontend provider page/tests: update imports and assertions to provider names/routes.
- Docs/smoke: update contract, current-status, smoke-matrix, basic/full smoke scripts.

## Tasks

### Task 1: Write failing backend/frontend contract tests

- [ ] Add/modify backend router tests to expect `/api/admin/v1/ai-providers` and reject old `/ai-engine-connections`.
- [ ] Add/modify frontend Vitest `tests/shared/ai/ai-provider-api.test.ts` to expect `src/api/ai/providers.ts`, `AiProviderApi`, `/ai-providers`, and no `engineConnections`/`AiEngineConnection`.
- [ ] Run targeted tests and verify RED.

### Task 2: Rename backend module and DB model

- [ ] Move module directory from `aiengine` to `aiprovider`.
- [ ] Replace package/import/type names.
- [ ] Change provider model TableName to `ai_providers`.
- [ ] Change route group to `/api/admin/v1/ai-providers`.
- [ ] Update server/bootstrap dependency names and route metadata permission codes.
- [ ] Run backend targeted tests until green.

### Task 3: Rename DB schema references and migrations

- [ ] Add migration to rename table and columns/indexes.
- [ ] Update rebuild/rollback/openai provider migrations.
- [ ] Update all repository joins and projection models from `engine_connection_id` to `provider_id`.
- [ ] Run backend module tests for provider/app/map/chat/run/server/bootstrap.

### Task 4: Rename frontend API and imports

- [ ] Move `engineConnections.ts` to `providers.ts`.
- [ ] Rename exported types/API object to `AiProvider*`.
- [ ] Update provider page imports and usages.
- [ ] Update frontend tests and run Vitest/vue-tsc.

### Task 5: Docs, smoke, real DB migration, residue scan

- [ ] Update docs/contracts, current-status, smoke-matrix.
- [ ] Update smoke scripts to call `/api/admin/v1/ai-providers` and provider naming.
- [ ] Backup real MySQL affected tables.
- [ ] Execute rename migration against local DB.
- [ ] Verify tables/columns/indexes.
- [ ] Run residue scan and diff check.
