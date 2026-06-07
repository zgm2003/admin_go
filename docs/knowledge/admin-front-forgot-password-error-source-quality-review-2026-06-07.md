# Admin Front Forgot Password Error Source Quality Review

Date: 2026-06-07

## Decision

`admin_front_ts/src/views/Login/composables/useForgotPassword.ts` request-error fallback debt has been closed.

The old code used `catch (error: any)` and `error?.message || t(...)` for send-code and reset-password failures. That hid malformed request errors with empty messages behind generic fallback text. The current code treats caught values as `unknown`, requires an `Error` instance, and requires a non-empty message before displaying it.

## Source change

```text
admin_front_ts/src/views/Login/composables/useForgotPassword.ts:
  catch (error: unknown)
  requireRequestErrorMessage(error, 'send code')
  requireRequestErrorMessage(error, 'reset')
  empty Error.message throws instead of falling back to sendFailed/resetFailed
  non-Error rejection throws instead of being stringified or hidden
```

Touched primitive state now uses `shallowRef`; `forgotForm` remains `reactive` because it is mutated field-by-field.

## Guard

```text
admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts:
  rejects catch (error: any)
  rejects error?.message || fallback
  verifies empty send-code request errors are not replaced with sendFailed
  verifies empty reset-password request errors are not replaced with resetFailed
```

## Inventory result after cleanup

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md:
  any candidates = 7
  as any candidates = 0
  fallback candidates = 562
  direct external HTTP candidates = 0
  useForgotPassword.ts no longer has catch-any or optional-chain error fallback rows
```

## Boundary

This only closes the request-error handling debt in forgot-password. The remaining `useForgotPassword.ts` logical-or rows are form validation predicates and remain inventory evidence for later review, not part of this error-message cleanup.



