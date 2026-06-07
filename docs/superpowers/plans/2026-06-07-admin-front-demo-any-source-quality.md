# Admin Front Demo Any Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining tracked Admin Vue `any` candidates in demo/display/effect code without hiding fallback debt.

**Architecture:** Keep existing demo components in place. Name the data structures at the local boundary and add source guards for the retired bad strings.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vitest, vue-tsc, PowerShell governance scripts.

---

## Files

- Modify: `admin_front_ts/src/views/Main/component/form/index.vue`
- Modify: `admin_front_ts/src/views/Main/component/display/index.vue`
- Modify: `admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue`
- Create: `admin_front_ts/tests/shared/form/form-demo-source-quality.test.ts`
- Create: `admin_front_ts/tests/shared/display/display-demo-source-quality.test.ts`
- Create: `admin_front_ts/tests/shared/effect/particle-background-source-quality.test.ts`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Create: `docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Sync docs: `docs/knowledge/README.md`, `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`

## Steps

- [x] Write RED source guard for form demo any/fallback rows.
- [x] Type form demo handler, icon ref, mock remote params, and table doc `Record<string, unknown>` row.
- [x] Write RED source guards for display demo and ParticleBackground.
- [x] Replace display doc `type: 'any'` with `Record<string, unknown>`.
- [x] Type ParticleBackground particle/pointer state and replace numeric `|| 1` fallbacks with explicit helpers.
- [x] Run targeted Vitest and `vue-tsc`.
- [x] Refresh Admin Vue source-quality inventory and confirm `280 files / 0 any / 559 fallback / 0 direct external HTTP`.
- [ ] Run runtime doc checks, diff checks, and governance check.
