# Admin AI Agent Test Contract Review

Date: 2026-06-07

## Decision

`POST /api/admin/v1/ai-agents/:id/test` is an active Admin Vue frontend gap that has been closed.

It is not a backend-only diagnostic endpoint and not a dead route. The backend already owns the agent/provider credential validation path and the route is mapped to `ai_agent_test`; the Admin Vue AI agent list now exposes that action directly.

## Source evidence

```text
Backend route:
admin_back_go/internal/module/ai/agent/transport/admin/route.go registers POST /api/admin/v1/ai-agents/:id/test.

Backend handler:
admin_back_go/internal/module/ai/agent/transport/admin/handler.go parses route id and calls service.Test(ctx, id).

Backend service:
admin_back_go/internal/module/ai/agent/service.go requires an enabled agent, active provider, configured provider API key, and calls tester.TestConnection.

Backend route metadata:
admin_back_go/internal/bootstrap/route_meta.go maps POST /api/admin/v1/ai-agents/:id/test to ai_agent_test and operation action test.

Frontend API:
admin_front_ts/src/api/ai/agents.ts exports AiAgentApi.test and calls POST /api/admin/v1/ai-agents/:id/test.

Frontend page:
admin_front_ts/src/views/Main/ai/agents/index.vue renders the test action only for userStore.can('ai_agent_test') and enabled rows.
```

## Runtime behavior

```text
enabled AI agent row + ai_agent_test permission:
  show Test action
  call POST /api/admin/v1/ai-agents/:id/test
  show i18n success notification after backend success

disabled AI agent row:
  hide Test action because backend rejects disabled agents

no ai_agent_test permission:
  hide Test action
```

No provider/model/API key data is accepted from the browser. The backend derives provider credentials from the selected agent and its active provider.

## API drift result

After adding the exact Admin frontend API call:

```text
docs/knowledge/frontend-backend-api-drift-2026-06-07.md:
  frontend exact backend API calls compared = 258
  frontend-route-match = 258
  frontend-method-mismatch = 0
  frontend-no-backend-route = 0
  backend admin/canvas source-only routes = 19

docs/knowledge/api-source-only-route-review-2026-06-07.md:
  source-only routes reviewed = 19
  owner-decision-required routes = 0
```

`API-DRIFT-001` has no remaining owner-decision-required route after this slice.

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```
