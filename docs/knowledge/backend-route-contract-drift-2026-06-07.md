# Backend Route Contract Drift Snapshot

Generated at: 2026-06-08 06:02:59 +08:00

Route source inventory: `docs/knowledge/backend-route-inventory-2026-06-07.md`

This artifact compares current Go backend route source inventory with current Markdown contracts/status/knowledge docs. It is a drift report, not served endpoint proof and not an automatic compatibility verdict.

Classification rules: `contract-exact` means a docs/contracts file contains the full route path; `contract-prefix-only` means only a resource prefix is mentioned; `source-docs-only` means status/knowledge mentions the exact path but contracts do not; `undocumented-exact` means no exact Markdown contract hit was found.

## Summary

| Fact | Value |
| --- | --- |
| Route inventory artifact | `docs/knowledge/backend-route-inventory-2026-06-07.md` |
| Route registrations compared | `298` |
| contract-exact | `298` |
| contract-prefix-only | `0` |
| source-docs-only | `0` |
| undocumented-exact | `0` |
| Callback exception registrations | `1` |

## Surface classification summary

| Surface | contract-exact | contract-prefix-only | source-docs-only | undocumented-exact |
| --- | ---: | ---: | ---: | ---: |
| `admin` | `258` | `0` | `0` | `0` |
| `app` | `9` | `0` | `0` | `0` |
| `callback` | `1` | `0` | `0` | `0` |
| `canvas` | `30` | `0` | `0` | `0` |

## Routes without exact contract hit

These rows need human review before editing contract docs. Prefix-only is not exact contract coverage.

| Class | Capability | Surface | Method | Path | Route source | Prefix hit | Permission code | Operation metadata |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
