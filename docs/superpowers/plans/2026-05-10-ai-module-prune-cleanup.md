# AI Module Prune Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 AI 模块从“历史堆功能”收回到 live MySQL + 当前 OpenAI-first runtime 的最小事实，删除旧表假真相、Dify/多引擎死代码、幻想枚举和残留权限。

**Architecture:** 真相顺序固定为 MySQL MCP -> 当前 Go runtime -> 当前 Vue 调用 -> 文档。DB 结构不从 `admin.sql` 推断；`admin.sql` 只能当 legacy dump，不能继续携带错误 AI DDL。先删不影响 runtime 的死代码和假文档，再处理需要 live DB 变更的权限数据。

**Tech Stack:** Go 1.26 / Gin / Gorm / MySQL / Vue 3 / TypeScript / Vitest / MySQL MCP.

---

## Linus 三问

1. 真问题吗？是。MySQL MCP 显示 live DB 只有 16 张 `ai_%` 表，但 `admin.sql`、Go AI engine interface、权限数据和枚举还在传播旧 AI 世界。
2. 更简单吗？有。先删除 active runtime 不可能用到的 Dify/多驱动分支和旧权限，不重命名 live DB 核心字段，不重做 UI。
3. 会破坏什么？禁止破坏登录、RBAC 菜单、AI 对话 WebSocket、供应商/智能体/知识库/工具/运行监控页面。所有删除都要用测试和 MCP 复核兜住。

## MySQL MCP live baseline（唯一表结构事实）

- 2026-05-10 MCP verified `DATABASE() = admin`.
- 当前 `ai_%` 表数量：16。
- 当前 live 表：
  1. `ai_agent_knowledge_bases`
  2. `ai_agent_tools`
  3. `ai_agents`
  4. `ai_conversations`
  5. `ai_knowledge_bases`
  6. `ai_knowledge_chunks`
  7. `ai_knowledge_documents`
  8. `ai_knowledge_retrieval_hits`
  9. `ai_knowledge_retrievals`
  10. `ai_messages`
  11. `ai_provider_models`
  12. `ai_providers`
  13. `ai_run_events`
  14. `ai_runs`
  15. `ai_tool_calls`
  16. `ai_tools`
- MCP confirmed absent old tables：`ai_agent_scenes`, `ai_assistant_tools`, `ai_models`, `ai_prompt`, `ai_prompts`, `ai_run_steps`, `ai_usage_daily`, `ai_apps`, `ai_app_bindings`, `ai_knowledge_maps`, `ai_tool_maps`, `ai_engine_connections`.
- MCP active stale permissions to retire：`ai_knowledge_sync`, `ai_knowledge_document_refresh`, `ai_agent_binding_del`.

## Delete / split / keep decisions

### Delete now

- `admin_back_go/internal/platform/ai/dify/`：active provider contract 是 OpenAI-first，local knowledge 不走 Dify dataset sync。
- `platformai.EngineTypeDify`, `EngineTypeEino`, `EngineTypeDirect`, `EngineTypeRAGFlow`：runtime 只接受 `openai`。
- `platformai.Engine.StopChat`, `SyncKnowledge`, `KnowledgeStatus` 及相关 input/result types：当前取消依赖 Go request context，本地知识库由 `aiknowledge` 负责，不是 provider API。
- `openaicompat` 的 Stop/Knowledge stub：stub 不是功能，只是接口污染。
- 测试 fixture 里的 Dify 假供应商名/URL。
- `enum/ai.go` 和 `dict/dict.go` 中只被测试引用的多 provider / mode / capability / retired scenes / visibility 幻想枚举。
- `admin.sql` 里的所有 AI DDL 区块：它不是 live truth，且当前包含不存在表和旧字段。
- live permission 残留：`ai_knowledge_sync`, `ai_knowledge_document_refresh`, `ai_agent_binding_del`，用 migration soft-delete 并清 role grants。

### Split now

- 新增 `docs/db/ai-live-schema-mcp-2026-05-10.md`：把 MySQL MCP 的 16 表 + 列清单单独落成审计快照，替代从 `admin.sql` 看 AI 结构。
- `admin.sql` 保留非 AI legacy dump；AI schema 入口指向 MCP 快照 + tracked migrations。

### Keep for now

- live 表 16 张都保留：它们都被当前 provider / agent / conversation / message / run / tool / knowledge runtime 使用或承载审计历史。
- `ai_messages.meta_json` 保留：live rows 已经有附件/runtime params 事实，不能为了“文本 MVP”硬删。
- `ai_providers.engine_type` 字段名暂不改：live schema 和前后端契约还在用，今天只砍非 OpenAI 分支，不做破坏性 rename。
- 前端 `MessageInput.vue` 暂不删图片/语音/emoji/runtime params：这属于产品范围回退，不属于本次安全减法。

## Files

- Modify: `admin_back_go/internal/platform/ai/types.go` — shrink provider engine contract.
- Modify: `admin_back_go/internal/platform/ai/fake.go` — remove fake stop/knowledge state.
- Delete: `admin_back_go/internal/platform/ai/dify/` — remove Dify client/tests.
- Modify: `admin_back_go/internal/platform/ai/openaicompat/client.go` — remove dead stub methods.
- Modify: `admin_back_go/internal/bootstrap/app.go` — remove Dify imports and switch branches.
- Modify: `admin_back_go/internal/module/aichat/service_test.go` — use OpenAI fixture and remove now-dead interface methods.
- Modify: `admin_back_go/internal/module/airun/service_test.go` — rename fake provider option from Dify to OpenAI.
- Modify: `admin_back_go/internal/enum/ai.go` — keep active message/run enums only.
- Modify: `admin_back_go/internal/dict/dict.go` — keep active run dict only.
- Delete: `admin_back_go/internal/enum/ai_test.go`, `admin_back_go/internal/enum/ai_agent_knowledge_test.go`, `admin_back_go/internal/dict/ai_test.go`, `admin_back_go/internal/dict/ai_agent_knowledge_test.go` — remove tests for deleted fantasy enums.
- Create: `admin_back_go/database/migrations/20260510_ai_prune_stale_permissions.sql` — soft-delete stale AI permission rows and role grants.
- Modify: `admin.sql` — remove all `ai_%` DDL sections and add an explicit MCP-truth note.
- Create: `docs/db/ai-live-schema-mcp-2026-05-10.md` — live schema snapshot from MCP.
- Modify: `docs/migration/current-status.md` — stop citing missing migration filenames; point to MCP snapshot.
- Modify: `admin_back_go/docs/architecture.md` — update AI migration list and OpenAI-only runtime boundary.

## Task 1: write live schema snapshot and remove admin.sql AI fake truth

- [x] Create `docs/db/ai-live-schema-mcp-2026-05-10.md` with the MCP 16-table list and compact column list.
- [x] Remove every `-- Table structure for ai_...` block from `admin.sql`.
- [x] Insert an `admin.sql` note: AI schema is intentionally split out; do not use this dump as AI schema truth.
- [x] Verify:

```powershell
rg -n "Table structure for ai_|ai_agent_scenes|ai_assistant_tools|ai_models|ai_prompt|ai_prompts|ai_run_steps|ai_usage_daily|executor_type|executor_config|run_status|model_snapshot" admin.sql
```

Expected: no AI table/old-field matches.

## Task 2: prune stale live AI permissions

- [x] Create migration `admin_back_go/database/migrations/20260510_ai_prune_stale_permissions.sql`.
- [x] Migration must soft-delete only these active stale codes: `ai_knowledge_sync`, `ai_knowledge_document_refresh`, `ai_agent_binding_del`.
- [x] Migration must soft-delete `role_permissions` rows linked to those permission IDs.
- [x] Apply the migration to the local DB if MySQL CLI is available.
- [x] Verify through MySQL MCP:

```sql
SELECT code, is_del FROM permissions WHERE code IN ('ai_knowledge_sync','ai_knowledge_document_refresh','ai_agent_binding_del');
```

Expected: all three rows have `is_del = 1` or no active `is_del = 2` rows.

## Task 3: remove Dify and shrink platform AI contract

- [x] Delete `admin_back_go/internal/platform/ai/dify/`.
- [x] In `types.go`, keep only `EngineTypeOpenAI` and the two real methods: `TestConnection`, `StreamChat`.
- [x] Remove Stop/Knowledge types and stub implementations from fake/openaicompat/test engines.
- [x] In `bootstrap/app.go`, remove Dify import and all Dify switch branches.
- [x] Update tests to use OpenAI fixture names.
- [x] Verify:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/ai ./internal/platform/ai/openaicompat ./internal/bootstrap ./internal/module/aichat ./internal/module/aitool ./internal/module/aiprovider ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/airun ./internal/server -count=1
```

Expected: PASS.

## Task 4: remove fantasy AI enum/dict surface

- [x] In `enum/ai.go`, delete only unused multi-provider/mode/capability/retired-scene/visibility/source/index enum blocks.
- [x] Keep active message roles, run statuses, and run events.
- [x] In `dict/dict.go`, delete unused AI option helpers; keep `AIRunStatusOptions`.
- [x] Delete tests that only assert removed fantasy enums.
- [x] Verify:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/enum ./internal/dict ./internal/module/airun ./internal/module/aichat -count=1
```

Expected: PASS.

## Task 5: sync docs to runtime truth

- [x] Update `docs/migration/current-status.md` so AI provider/status rows no longer cite missing migration files as if they exist.
- [x] Update `admin_back_go/docs/architecture.md` AI boundary: runtime is OpenAI-compatible only; no Dify adapter in active source; live schema snapshot is in `docs/db/ai-live-schema-mcp-2026-05-10.md`.
- [x] Verify doc residue:

```powershell
rg -n "20260509_ai_openai_provider_config|20260509_cleanup_ai_provider_models_snapshot|20260509_rename_ai_engine_connections_to_providers|internal/platform/ai/dify|EngineTypeDify|EngineTypeEino|EngineTypeDirect|EngineTypeRAGFlow" docs admin_back_go/docs admin_back_go/internal
```

Expected: no active-source hits; docs may mention Dify only as explicit negative/historical context.

## Task 6: final verification ladder

- [x] MySQL MCP table count remains 16 for `ai_%`.
- [x] MySQL MCP absent-table check still reports zero for retired old tables.
- [x] Backend focused tests pass.
- [x] Frontend AI contract tests/typecheck if touched; this pass should not touch frontend UI.
- [x] `git diff --check` passes.
- [x] `rg` residue scan shows no active Dify runtime code and no stale AI DDL in `admin.sql`.


## Execution verification

2026-05-10 final checks:

- MySQL MCP `DATABASE()` = `admin`.
- MySQL MCP `ai_%` table count = `16`; retired old AI tables all `exists_count = 0`.
- MySQL MCP stale permissions `ai_knowledge_sync`, `ai_knowledge_document_refresh`, `ai_agent_binding_del` now have `is_del = 1`; active stale role grants = `0`.
- Backend focused tests passed with low parallelism to avoid local Windows memory pressure:

```powershell
cd E:/admin_go/admin_back_go
$env:GOMAXPROCS='2'
go test -p 1 ./internal/enum ./internal/dict ./internal/module/airun ./internal/module/aichat -count=1
go test -p 1 ./internal/platform/ai ./internal/platform/ai/openaicompat ./internal/bootstrap ./internal/module/aichat ./internal/module/aitool ./internal/module/aiprovider ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/airun ./internal/server -count=1
go test -p 1 ./... -run '^$' -count=1
```

- `admin.sql` stale AI DDL residue scan: no matches.
- active source Dify/runtime residue scan: no matches.
- active docs/source residue scan excluding historical `docs/superpowers/**`: no matches. Historical plans/specs intentionally keep old design context.
- `git diff --check` passed for meta repo and `admin_back_go`.
- Frontend code was not touched in this pass, so frontend contract/typecheck was not required for this cleanup slice.
