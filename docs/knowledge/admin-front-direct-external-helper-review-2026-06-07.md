# Admin Front Direct External Helper Review

Date: 2026-06-07

## Decision

`admin_front_ts/src/api/tools.ts` was an unused Admin Vue helper and has been deleted.

The file exported `getRondomImage()` and called `https://api.btstu.cn/sjbz/api.php` through direct `axios.get`. Current source search found no active import or runtime caller under `admin_front_ts/src` or `admin_front_ts/tests`, so this was not an owned product contract. Keeping it would preserve a silent third-party random-image fallback with no Admin API owner, no i18n/error contract, and no backend boundary.

## Source evidence

```text
Removed file:
admin_front_ts/src/api/tools.ts

Deleted helper:
getRondomImage()

Retired external host:
https://api.btstu.cn/sjbz/api.php

Active usage proof:
rg getRondomImage/getRandomImage/btstu/sjbz/api/tools under admin_front_ts/src and admin_front_ts/tests only found the helper file before deletion.
```

## Runtime behavior

No UI behavior changes are expected because no active source imports the helper. If a future random/background image feature is required, it needs an explicit product owner and contract instead of reintroducing a direct browser-side external helper.

## Inventory result after deletion

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md:
  source files scanned = 280
  direct external HTTP candidates = 0

docs/knowledge/frontend-api-inventory-2026-06-07.md:
  frontend API calls found = 274
  external HTTP calls = 3
  no https://api.btstu.cn/sjbz/api.php row
```

## Guard

```text
admin_front_ts/tests/shared/api/no-direct-external-helper.test.ts asserts:
  - admin_front_ts/src/api/tools.ts does not exist
  - Admin Vue source does not contain api.btstu.cn

scripts/check-runtime-doc-facts.ps1 asserts:
  - frontend API inventory does not contain https://api.btstu.cn/sjbz/api.php
  - Admin front source-quality inventory direct external HTTP candidates = 0
  - the deleted helper path and external host are absent from the inventory
```
