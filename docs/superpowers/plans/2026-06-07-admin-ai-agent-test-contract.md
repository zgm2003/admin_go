# Admin AI Agent Test Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the last API-DRIFT-001 owner decision by making `POST /api/admin/v1/ai-agents/:id/test` an active Admin Vue frontend call.

**Architecture:** Keep the Go backend route/service unchanged. Add one typed `AiAgentApi.test()` wrapper and expose one row action in the existing AI agent list under `ai_agent_test`. Regenerate source inventory/drift docs so unknown source-only owner decisions go to zero instead of being hidden.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vite/Vitest source guards, Element Plus notification, Go/Gin route evidence, PowerShell generated docs/fact guards.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-admin-ai-agent-test-contract-design.md`

### File map

```text
admin_front_ts/tests/shared/ai/ai-agent-api.test.ts
  Source guard for the typed wrapper, route path, page action, permission code, and no legacy/fallback API usage.

admin_front_ts/src/api/ai/agents.ts
  Owns the Admin Vue typed AI agent API client.

admin_front_ts/src/views/Main/ai/agents/index.vue
  Owns the AI agent management table and row actions.

admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
  Own visible button/notification text.

docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md
  Records the source decision and evidence.

docs/knowledge/*.md, docs/status/*.md
  Runtime knowledge/status indexes updated after generated artifacts refresh.

scripts/check-runtime-doc-facts.ps1
  Guards the new review artifact, zero owner-decision count, and exact frontend call.
```

### Task 1: Confirm route ownership

**Files:**
- Read: `admin_back_go/internal/module/ai/agent/transport/admin/route.go`
- Read: `admin_back_go/internal/module/ai/agent/transport/admin/handler.go`
- Read: `admin_back_go/internal/module/ai/agent/service.go`
- Read: `admin_back_go/internal/bootstrap/route_meta.go`
- Read: `docs/contracts/admin-api-v1.md`
- Read: `admin_front_ts/src/api/ai/agents.ts`
- Read: `admin_front_ts/src/views/Main/ai/agents/index.vue`

- [ ] **Step 1: Confirm backend route exists**

Expected source facts:

```text
group.POST("/:id/test", handler.Test)
handler.Test parses route id and calls service.Test(ctx, id)
service.Test validates enabled agent, active provider, configured provider API key, then calls tester.TestConnection
route_meta.go maps POST /api/admin/v1/ai-agents/:id/test to ai_agent_test
operation metadata records module=ai_agent action=test title=测试AI智能体
docs/contracts/admin-api-v1.md lists POST /api/admin/v1/ai-agents/:id/test under AI Agents / Agents
```

- [ ] **Step 2: Confirm frontend gap exists**

Expected source facts before implementation:

```text
AiAgentApi has no test wrapper.
tests/shared/ai/ai-agent-api.test.ts currently forbids '/test`)' for agents.
AI agent page has provider/tool/knowledge/status/delete row actions but no ai_agent_test action.
docs/knowledge/api-source-only-route-review-2026-06-07.md lists POST /api/admin/v1/ai-agents/:id/test as owner-decision-required.
```

### Task 2: Red guard test

**Files:**
- Modify: `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts`

- [ ] **Step 1: Add failing source guards**

Change the API contract test so it requires:

```ts
expect(source).toContain('export interface AiAgentTestResult')
expect(source).toContain('request.post<AiAgentTestResult>(`${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, \\'AI agent id\\')}/test`)')
```

Remove the old negative assertion:

```ts
expect(source).not.toContain('/test`)')
```

Add page assertions to the route-view test:

```ts
expect(source).toContain("import { useUserStore } from '@/store/user'")
expect(source).toContain('const userStore = useUserStore()')
expect(source).toContain('async function testConnection(row: AiAgentItem)')
expect(source).toContain('await AiAgentApi.test({ id: row.id })')
expect(source).toContain("ElNotification.success({ message: t('aiAgents.testDone') })")
expect(source).toContain("userStore.can('ai_agent_test') && row.status === CommonEnum.YES")
expect(source).toContain('@click="testConnection(row)"')
expect(source).toContain("{{ t('aiAgents.actions.test') }}")
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts
```

Expected before implementation:

```text
FAIL because AiAgentTestResult, AiAgentApi.test, useUserStore, testConnection, and the ai_agent_test button are missing.
```

### Task 3: Minimal frontend implementation

**Files:**
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Add typed API result and wrapper**

In `agents.ts`, add:

```ts
export interface AiAgentTestResult {
  ok: boolean
  status?: string
  latency_ms?: number
  message?: string
  model_count?: number
}
```

Add to `AiAgentApi`:

```ts
test: (params: { id: Id }) => request.post<AiAgentTestResult>(`${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, 'AI agent id')}/test`),
```

- [ ] **Step 2: Add page action**

In `index.vue`, add:

```ts
import { useUserStore } from '@/store/user'
```

After `const isMobile = useIsMobile()` add:

```ts
const userStore = useUserStore()
```

Add:

```ts
async function testConnection(row: AiAgentItem) {
  await AiAgentApi.test({ id: row.id })
  ElNotification.success({ message: t('aiAgents.testDone') })
}
```

Add the row action before tool/knowledge actions:

```vue
<el-button
  v-if="userStore.can('ai_agent_test') && row.status === CommonEnum.YES"
  type="success"
  text
  @click="testConnection(row)"
>
  {{ t('aiAgents.actions.test') }}
</el-button>
```

- [ ] **Step 3: Add i18n keys**

In `zh-CN.ts`:

```ts
actions: { test: '测试连接', tools: '工具配置', knowledge: '知识库' },
testDone: '智能体连接测试完成',
```

In `en-US.ts`:

```ts
actions: { test: 'Test', tools: 'Tool Config', knowledge: 'Knowledge' },
testDone: 'Agent connection test completed',
```

### Task 4: Green verification and generated artifacts

**Files:**
- Modify generated: `docs/knowledge/frontend-api-inventory-2026-06-07.md`
- Modify generated: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`
- Modify generated: `docs/knowledge/api-source-only-route-review-2026-06-07.md`
- Modify generated: `docs/knowledge/full-stack-module-map-2026-06-07.md`

- [ ] **Step 1: Run target frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts
npm run typecheck
```

- [ ] **Step 2: Run exporters in order**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```

Expected:

```text
frontend exact backend API calls increases from 257 to 258.
backend source-only rows decreases from 20 to 19.
owner-decision-required routes decreases from 1 to 0.
POST /api/admin/v1/ai-agents/:id/test is absent from source-only review.
```

### Task 5: Knowledge/status/fact guard sync

**Files:**
- Create: `docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Add review artifact**

Record:

```text
POST /api/admin/v1/ai-agents/:id/test is an active Admin Vue frontend gap now closed.
Frontend calls AiAgentApi.test from the AI agent list row action.
The row action is visible only under ai_agent_test and enabled rows.
API-DRIFT-001 has zero owner-decision-required routes after regeneration.
```

- [ ] **Step 2: Update fact guard**

Require:

```text
frontend inventory contains POST /api/admin/v1/ai-agents/:param/test
source-only review does not contain /api/admin/v1/ai-agents/:id/test
owner-decision count is 0
full-stack module map owner-decision count is 0
new review artifact is indexed from README/current-runtime/source-map/status
admin_front_ts/src/api/ai/agents.ts contains AiAgentApi.test
admin_front_ts/src/views/Main/ai/agents/index.vue contains ai_agent_test and testConnection(row)
tests/shared/ai/ai-agent-api.test.ts contains the source guard
docs/status/known-issues.md records API-DRIFT-001 as resolved
```

- [ ] **Step 3: Root verification**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
