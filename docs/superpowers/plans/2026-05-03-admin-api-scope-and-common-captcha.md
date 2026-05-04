# Admin API Scope and Common Captcha Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` if this plan is resumed later. Current session executes inline because the user explicitly asked to write the plan and start immediately.

**Goal:** Give the Go rewrite a clean application-scoped admin API prefix and make slide captcha a reusable frontend capability instead of a login-private widget.

**Architecture:** Go routes move from `/api/v1/...` to `/api/admin/v1/...`; future app routes can live under `/api/app/v1/...`. Frontend API clients use one admin API prefix constant. Captcha UI moves under `src/components/AppCaptcha/**`; login composes the common dialog and owns only login flow state.

**Tech Stack:** Gin, Go tests, Vue 3 `<script setup lang="ts">`, Element Plus, existing `AppDialog`, existing go-captcha DTO contract.

---

## Tasks

### Task 1: API scope contract
- Change Go admin-owned routes to `/api/admin/v1/...`.
- Update auth public skip paths, route metadata, tests, smoke script, and docs.
- Do not add `/api/v1` compatibility routes.

### Task 2: Frontend admin API prefix
- Add a small `ADMIN_API_PREFIX = '/api/admin/v1'` constant.
- Update `UsersApi`, permission API, role API, and refresh-token path.
- Update focused API contract tests.

### Task 3: Common captcha component
- Create `src/types/captcha.ts` for shared DTOs.
- Create `src/components/AppCaptcha/src/AppSlideCaptcha.vue` as a pure display component.
- Create `src/components/AppCaptcha/src/AppCaptchaDialog.vue` using existing `AppDialog`.
- Export both from `src/components/AppCaptcha/index.ts`.

### Task 4: Login composition
- Remove inline captcha from `LoginFormCard.vue`.
- In `useLoginForm.ts`, open captcha dialog after form/policy validation and submit login only after dialog confirmation.
- Keep failed password login inside the dialog and refresh captcha after failure.

### Task 5: Verification
- Run Go tests.
- Run focused frontend API tests.
- Run `vue-tsc` if dependency state allows.
