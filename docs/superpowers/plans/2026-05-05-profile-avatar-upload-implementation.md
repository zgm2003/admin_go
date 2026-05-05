# Profile Avatar Upload Implementation Plan

> REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for sequential execution. Do not commit. Current branch only.

## Goal

Migrate the personal profile base-info flow to Go REST and make avatar the first real business upload scenario using the already implemented COS-first upload token runtime.

## Steps

- [ ] Add backend failing tests for profile read/update service behavior.
- [ ] Add handler tests for `GET /profile`, `GET /users/:id/profile`, `PUT /profile`, including rejecting legacy `address` alias.
- [ ] Add route metadata tests for profile update operation log and no button permission requirement.
- [ ] Implement user model/profile DTO/request/service/repository/handler/route changes.
- [ ] Update router fake service tests if interface changes.
- [ ] Adapt frontend user types and API client to Go profile contract.
- [ ] Adapt `personal/index.vue`, `BaseInfo`, and home profile summary to `address_id` + `profile/dict` response.
- [ ] Keep phone/email/password calls legacy for now and document that boundary.
- [ ] Update contract/current-status/smoke-matrix/backend architecture docs.
- [ ] Run backend targeted tests, then full backend gates.
- [ ] Run frontend typecheck and targeted eslint.

## Design Constraints

- Do not create a separate profile micro-module unless the user module becomes unreadable. `user` is the existing owner of `users` and `user_profiles`.
- Do not add compatibility fallback fields like `address` in the new API.
- Do not require `user_userManager_edit` to edit your own profile.
- Do not install a new upload component or cloud SDK; reuse existing `UpMedia` and `uploadClient`.
- Do not migrate security flows in this slice.
