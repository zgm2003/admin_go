# Admin Front useValidator Source Quality Review

日期：2026-06-07

## Outcome

Admin `useValidator` validator input typing and message fallback debt is closed.

`src/hooks/web/useValidator.ts` now accepts typed string validator values, resolves optional custom messages with an explicit helper, and no longer hides validator message bugs behind `message || fallback`.

## Evidence

```text
source file = admin_front_ts/src/hooks/web/useValidator.ts
guard test = admin_front_ts/tests/shared/validator/use-validator-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 7
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 562
direct external HTTP candidates = 0
useValidator.ts priority evidence = no any/message fallback rows; only validation predicate logical-or remains
```

Key source facts:

- `ValidatorValue` is the validator input type for string validators.
- `LengthRange` owns the explicit `{ min, max, message? }` shape.
- `resolveValidatorMessage(message, fallback)` preserves provided empty messages and only uses the i18n fallback when `message === undefined`.
- `lengthRange`, `notSpace`, `notSpecialCharacters`, `isEmail`, `isMobile`, and `isUrl` no longer accept `val: any`.

## Compatibility

Preserved:

```text
useValidator() exported composable shape
required/lengthRange/notSpace/notSpecialCharacters/isEqual/isEmail/isMobile/isUrl names
Element Plus callback contract
existing i18n keys under common.*
```

Changed deliberately:

```text
custom empty validator messages are no longer overwritten by fallback text
validator values are typed as strings instead of any
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/validator/use-validator-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Observed inventory after refresh:

```text
source_files_scanned=280
any_candidates=7
as_any_candidates=0
catch_error_any_candidates=0
fallback_candidates=562
direct_external_http_candidates=0
```

## Boundary

This closes only the `useValidator.ts` validator input `any` and message fallback slice.

It does not close the remaining general Admin Vue `any` and fallback review rows. Keep reviewing one narrow slice at a time; do not regex-sweep the inventory.
