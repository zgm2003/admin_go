# Admin Front Direct External Helper Cleanup Design

Date: 2026-06-07

## Requirement

Close `ADMIN-FRONT-HARDENING-003` without inventing ownership for an unused direct external HTTP helper.

## Decision

Delete `admin_front_ts/src/api/tools.ts` if active usage proof shows no import/caller. Do not migrate it to `@/lib/http`, because the target URL is not a backend Admin API contract and no active feature owns the random image behavior.

## Guard

Add a source guard that fails while the helper file exists and rejects the retired `api.btstu.cn` host anywhere under Admin Vue source.

## Documentation

Regenerate Admin Vue source-quality inventory and frontend API inventory. Record the deletion in a knowledge review artifact, status, and runtime source map. Keep remaining `any/as any/fallback` inventory as review debt; this slice only closes the direct external helper.
