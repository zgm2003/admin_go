# Plan: Backend Capability Manifest

Date: 2026-06-07

## Steps

1. Add `scripts/export-backend-capability-manifest.ps1`.
   - Discover latest backend route inventory and DB schema ownership map.
   - Parse route capabilities/surfaces/route files.
   - Parse DB model-owner tables.
   - Enumerate current non-transport Go source packages under `admin_back_go/internal/module`.
   - Emit real capabilities and helper packages separately.

2. Generate `docs/knowledge/backend-capability-manifest-2026-06-07.md`.
   - Include summary counts.
   - Include per-capability source dir, service/repository/model/source/test files, route counts, surfaces, table ownership.
   - Include helper package list.

3. Sync docs.
   - `docs/knowledge/README.md`
   - `docs/knowledge/current-runtime-knowledge.md`
   - `docs/knowledge/runtime-source-map.md`
   - `docs/architecture/02-agent-framework.md`
   - `docs/status/current-status.md`

4. Extend `scripts/check-runtime-doc-facts.ps1`.
   - Discover latest backend capability manifest.
   - Verify it references latest backend route inventory and DB schema ownership.
   - Verify route count matches `280`.
   - Verify required capabilities exist: `ai/agent`, `payment/wallet`, `notification/task`, `auth`, `user`.
   - Verify helper packages are not promoted: `auth/verifycode`, `payment/serialno`, `queuemonitor/asynqmonui`.

5. Verify.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
