# Plan: Full-stack Module Map

Date: 2026-06-07

## Steps

1. Add `scripts/export-full-stack-module-map.ps1`.
   - Discover latest backend route, frontend API, DB schema ownership, and source-only review artifacts.
   - Parse markdown tables from those artifacts.
   - Join frontend exact backend calls to backend route capability by method + normalized route path.
   - Fail if any exact backend-prefixed frontend call cannot be mapped.

2. Generate `docs/knowledge/full-stack-module-map-2026-06-07.md`.
   - Include summary counts.
   - Include platform route counts.
   - Include per-capability route/frontend/table/source-only review map.

3. Sync knowledge docs.
   - `docs/knowledge/README.md`
   - `docs/knowledge/current-runtime-knowledge.md`
   - `docs/knowledge/runtime-source-map.md`
   - `docs/architecture/02-agent-framework.md`
   - `docs/status/current-status.md`

4. Extend `scripts/check-runtime-doc-facts.ps1`.
   - Discover latest full-stack module map artifact.
   - Verify artifact references latest source artifacts.
   - Verify backend route count is `280`.
   - Verify frontend exact backend calls assigned is `258`.
   - Verify unassigned frontend exact backend calls is `0`.
   - Verify live DB tables mapped is `56`.
   - Verify owner-decision-required routes remains `0`.
   - Verify key capabilities exist: `auth`, `user`, `permission`, `ai/agent`, `canvas`, `payment`, `payment/wallet`.

5. Run verification.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
