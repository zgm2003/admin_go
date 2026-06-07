# Admin Front Forgot Password Error Source Quality Design

Date: 2026-06-07

## Requirement

Remove `catch(error: any)` and `error?.message || fallback` from `admin_front_ts/src/views/Login/composables/useForgotPassword.ts` without changing the forgot-password UI flow.

## Design

Keep the composable as the owner of forgot-password dialog state. Add a small pure helper `requireRequestErrorMessage(error, operation)` that accepts `unknown`, requires an `Error`, requires a non-empty message, and returns the backend/client message for `ElMessage.error`.

This avoids silently replacing malformed request errors with generic i18n fallback text. Generic `sendFailed` / `resetFailed` strings are not used as catch-all fallbacks in this path.

## Non-goals

```text
Do not rewrite forgot-password validation predicates.
Do not change UsersApi contracts.
Do not change login page components or backend auth behavior.
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/forgot-password-source-quality.test.ts
npm run typecheck
```
