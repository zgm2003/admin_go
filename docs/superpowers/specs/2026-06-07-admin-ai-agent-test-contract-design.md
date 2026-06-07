# Admin AI Agent Test Contract Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。`POST /api/admin/v1/ai-agents/:id/test` 已经是 Go 后端 active route，并有 route metadata、operation log metadata、service tests 和 `ai_agent_test` 权限码；当前 Admin Vue `src/api/ai/agents.ts` 没有 `AiAgentApi.test()`，`src/views/Main/ai/agents/index.vue` 也没有测试动作，导致它留在 API-DRIFT-001 owner-decision backlog。

【核心问题】
把这个 route 判定为 active Admin Vue frontend gap 并闭环：AI 智能体列表页应在 `ai_agent_test` 权限下暴露“测试连接”动作，调用专用 `POST /api/admin/v1/ai-agents/:id/test`。不要把它归为 backend-only diagnostic，也不要借 provider test 或 batch/edit 兜底。

【复杂度检查】
不新增弹窗、不新增表结构、不改 Go route/service。智能体测试当前只需要复用后端返回的 `ok/status/latency_ms/message/model_count` 形状，在列表行增加一个按钮和一个 API wrapper。比起新增状态机或单独测试页，最小按钮动作足够。

【破坏性分析】
不改变 existing AI agent CRUD、provider/model selector、tool/knowledge binding、Canvas agent scene 语义。新增按钮只在已有 `ai_agent_test` 权限下显示；无权限用户不受影响。后端错误继续由统一 HTTP client/Element Plus notification 流程暴露，不做 silent fallback。

## 代码分析

【数据结构】
后端测试结果复用 `infraai.TestConnectionResult`：

```text
ok: boolean
status: string
latency_ms: number
message: string
model_count: number
```

前端新增 `AiAgentTestResult`，字段语义和 provider test result 对齐，但保持 agent API 自己的显式 contract。

【特殊情况】
如果后端返回错误，前端不吞错、不本地清 session、不假装成功。按钮动作只等待 `AiAgentApi.test()`，成功后显示固定 i18n 成功消息；不根据可选 `message` 猜测兜底文案。

【复杂度】
只触碰：

```text
admin_front_ts/src/api/ai/agents.ts
admin_front_ts/src/views/Main/ai/agents/index.vue
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
admin_front_ts/tests/shared/ai/ai-agent-api.test.ts
docs/knowledge/*
docs/status/*
scripts/check-runtime-doc-facts.ps1
```

【兼容性】
不删除后端 route，不改 response envelope，不改 permission code。`ai_agent_test` 已经在 route metadata 中存在，前端只消费该 code。

【结论】
值得做。它关闭 API-DRIFT-001 最后一条 owner decision，让 source-only review 从 `1` 收敛到 `0`，并把“backend route 已实现但前端不用”的漂移消掉。

## Acceptance criteria

- `admin_front_ts/src/api/ai/agents.ts` exports:

```ts
export interface AiAgentTestResult {
  ok: boolean
  status?: string
  latency_ms?: number
  message?: string
  model_count?: number
}
```

- `AiAgentApi.test(params)` calls:

```ts
request.post<AiAgentTestResult>(`${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, 'AI agent id')}/test`)
```

- `admin_front_ts/src/views/Main/ai/agents/index.vue` imports `useUserStore`, defines `testConnection(row)`, and renders the test button only when:

```text
userStore.can('ai_agent_test') && row.status === CommonEnum.YES
```

- The button label and success notification use `aiAgents.actions.test` and `aiAgents.testDone` in both zh-CN and en-US.
- `tests/shared/ai/ai-agent-api.test.ts` guards the API wrapper, page button, permission code, and absence of legacy `/bindings` / browser Authorization construction.
- Generated API artifacts show:

```text
frontend exact backend API calls compared = 258
backend admin/canvas source-only routes = 19
owner-decision-required routes = 0
```

- `docs/status/known-issues.md` closes `API-DRIFT-001`; no owner-decision candidate remains.
- `scripts/check-runtime-doc-facts.ps1 -LiveSchema`, Admin Vue targeted test/typecheck, `git diff --check`, and `check-agent-governance.ps1 -Mode working` pass.
