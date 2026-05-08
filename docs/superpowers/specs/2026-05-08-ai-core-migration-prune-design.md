# AI Core Migration Prune Design

状态：initial design for AI migration Phase 0。
日期：2026-05-08

本文只处理 **AI 迁移前的边界收口**：保留 AI 核心能力，删除 AI 电商口播和 AI 短剧工厂两个产品模块。缓存/Redis 清理由人工处理；本文不把缓存清理写进 DB migration。

## Linus 三问

1. 真问题：是。AI 是后续最核心模块，但当前 AI 菜单里混着两个已经决定删除的产品模块：`/ai/goods` 和 `/ai/cine`。如果不先清表结构和菜单权限，Go 迁移会把废模块也一起搬过去，后面更难砍。
2. 更简单做法：先做一刀清晰的 Phase 0：DB 表结构删除 + 菜单/授权删除 + 前端入口删除 + 文档真相同步。不要一边删废模块一边写 Go AI runtime。
3. 会破坏什么：会破坏 `/ai/goods`、`/ai/cine`、旧 PHP `Goods/Cine` 接口、对应历史业务表和菜单。不能破坏 `/ai/models`、`/ai/agents`、`/ai/knowledge`、`/ai/chat`、`/ai/runs`、`/ai/prompts`、`/ai/tools`，也不能硬删会被 AI 会话/运行历史引用的 agent/run/message 记录。

## 已确认运行事实

### 当前代码边界

```text
E:/admin_go 是 meta repo。
Go 后端真实仓库：E:/admin_go/admin_back_go。
Vue 前端真实仓库：E:/admin_go/admin_front_ts。
当前 Go 后端没有 internal/module/ai；AI 前端仍通过 legacyRequest 调用 E:/admin/admin_back 的 PHP AI 接口。
```

前端 AI API 当前状态：

```text
src/api/ai/models.ts          -> legacyRequest /api/admin/AiModels/*
src/api/ai/agents.ts          -> legacyRequest /api/admin/AiAgents/*
src/api/ai/knowledge.ts       -> legacyRequest /api/admin/AiKnowledgeBases/*
src/api/ai/chat.ts            -> legacyRequest /api/admin/AiChat/*
src/api/ai/runs.ts            -> legacyRequest /api/admin/AiRuns/*
src/api/ai/prompts.ts         -> legacyRequest /api/admin/AiPrompts/*
src/api/ai/tools.ts           -> legacyRequest /api/admin/AiTools/*
src/api/ai/goods.ts           -> legacyRequest /api/admin/Goods/*        # delete
src/api/ai/cine.ts            -> legacyRequest /api/admin/Cine/*         # delete
```

### 当前 DB 表结构

保留的 AI 核心表：

```text
ai_models
ai_agents
ai_agent_scenes
ai_agent_knowledge_bases
ai_assistant_tools
ai_tools
ai_conversations
ai_messages
ai_runs
ai_run_steps
ai_prompts
ai_knowledge_bases
ai_knowledge_documents
ai_knowledge_chunks
```

暂不在 Phase 0 删除的兼容/历史表：

```text
ai_prompt
```

原因：当前 PHP `AiPromptsModel` 使用 `ai_prompts`，但 live DB 仍有 `ai_prompt` 旧表和 5 行数据。Phase 0 不把“删除废产品模块”和“合并 prompt 历史表”混在一起。AI 核心迁移的 P1 会单独决定 `ai_prompts` canonical，并用数据 diff 处理 `ai_prompt`。

删除的产品模块表：

```text
goods           # AI 电商口播模块，当前 9 行，active 5 行
cine_projects   # AI 短剧工厂项目，当前 1 行，active 1 行
cine_assets     # AI 短剧工厂素材，当前 10 行，active 5 行
```

### 当前 DB 菜单/权限

AI 根菜单当前保留：

```text
id=5  AI助手
/ai/models       模型配置
/ai/agents       智能体
/ai/knowledge    知识库
/ai/chat         对话
/ai/runs         运行监控
/ai/prompts      提示词
/ai/tools        AI工具管理
```

本轮删除：

```text
id=93   /ai/goods   component=ai/goods   i18n_key=menu.ai_goods   role grants=3
id=121  /ai/cine    component=ai/cine    i18n_key=menu.ai_cine    role grants=1
```

### 当前 scene / agent 事实

产品模块 scene：

```text
goods_script    -> ai_agents id=1、id=3；合计 conversation=9、run=28
cine_project    -> ai_agents id=62；conversation=1、run=16
cine_keyframe   -> ai_agents id=63；conversation=2、run=2
```

这些 agent 不能硬删。`ai_conversations`、`ai_runs`、`ai_messages` 需要保留历史审计。Phase 0 只把它们软删除/禁用，让新 UI 不再可选。

产品模块 tool：

```text
ai_tools.code=cine_generate_keyframe 当前 is_del=2，需要软删除。
ai_assistant_tools 里绑定 retired scene agent 或 cine tool 的行需要软删除。
```

### 当前 cron 事实

AI 相关 active cron 只有：

```text
cron_task.name=ai_run_timeout
handler=app\\process\\AiRunTimeoutTask
status=1
is_del=2
```

这属于 AI 核心运行监控/超时补偿，不属于 goods/cine，本轮不删除。AI 核心迁移时必须把它变成 Go worker task type，不能留下 PHP handler 字符串冒充已迁移。

## 删除边界

### 必须删除

```text
DB tables: goods, cine_projects, cine_assets
DB permissions: /ai/goods, /ai/cine and their descendants if any
DB grants: role_permissions for removed permissions
DB quick entries: users_quick_entry for removed permissions, soft-delete before permission delete
DB AI scene selectors: ai_agent_scenes.scene_code in goods_script/cine_project/cine_keyframe -> is_del=1,status=2
DB scene agents: ai_agents.scene in goods_script/cine_project/cine_keyframe -> is_del=1,status=2
DB tool binding: ai_assistant_tools for retired scene agents or retired tools -> is_del=1,status=2
DB product tool: ai_tools.code=cine_generate_keyframe -> is_del=1,status=2
Frontend: src/api/ai/goods.ts, src/api/ai/cine.ts, src/views/Main/ai/goods, src/views/Main/ai/cine
Frontend i18n: menu.ai_goods/menu.ai_cine and top-level goods/cine locale blocks
Frontend tests: tests that import goods/cine modules
Docs/contracts: remove goods_tts/cine_keyframes upload folders from active contract
Go enum: remove goods_tts/cine_keyframes from active UploadFolders
```

### 必须保留

```text
ai_chat_images upload folder
AI core menu and pages: models/agents/knowledge/chat/runs/prompts/tools
AI core tables: ai_models, ai_agents, ai_conversations, ai_messages, ai_runs, ai_run_steps, ai_tools, ai_assistant_tools, ai_prompts, AI knowledge tables
AI run/message history referencing retired agents
cron_task ai_run_timeout row, until Go AI worker replacement exists
```

### 明确不做

```text
不清 Redis/button grant cache；用户已说明缓存自己处理。
不删对象存储里的 goods_tts / cine_keyframes 历史文件；这不是表结构。
不迁 Go AI API；Phase 0 完成后再按模型/工具/提示词/智能体/知识库/聊天/运行监控分计划迁移。
不把 /api/admin/Goods 或 /api/admin/Cine 做 Go adapter；产品已删除，不给废接口续命。
不删除 ai_prompt；该旧表归 AI core P1 canonical prompt migration 处理。
```

## Phase 0 DB 迁移策略

迁移文件：

```text
admin_back_go/database/migrations/20260508_remove_ai_goods_cine_modules.sql
```

策略：

```text
1. 用临时表收集 /ai/goods 和 /ai/cine 权限 id，避免手写当前 id。
2. 先软删 users_quick_entry，硬删 role_permissions，再硬删 permissions。
3. 用临时表收集 scene agent id 和 retired tool id。
4. 软删 agent scene、agent、assistant tool binding、cine tool。
5. 按依赖顺序 drop cine_assets -> cine_projects -> goods。
6. 不碰 Redis/cache。
```

迁移后 DB 验证必须为零：

```sql
SELECT COUNT(*) AS table_left
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('goods', 'cine_projects', 'cine_assets');

SELECT COUNT(*) AS permission_left
FROM permissions
WHERE platform = 'admin'
  AND is_del = 2
  AND (
    path IN ('/ai/goods', '/ai/cine')
    OR component IN ('ai/goods', 'ai/cine')
    OR i18n_key IN ('menu.ai_goods', 'menu.ai_cine')
  );

SELECT COUNT(*) AS active_scene_left
FROM ai_agent_scenes
WHERE is_del = 2
  AND scene_code IN ('goods_script', 'cine_project', 'cine_keyframe');

SELECT COUNT(*) AS active_scene_agent_left
FROM ai_agents
WHERE is_del = 2
  AND scene IN ('goods_script', 'cine_project', 'cine_keyframe');

SELECT COUNT(*) AS active_cine_tool_left
FROM ai_tools
WHERE is_del = 2
  AND code = 'cine_generate_keyframe';
```

## AI core migration roadmap after prune

P0 is this document: prune dead product modules.

P1：AI config read/write baseline。

```text
Go modules: aimodel, aitool, aiprompt
Tables: ai_models, ai_tools, ai_prompts
Frontend: src/api/ai/models.ts/tools.ts/prompts.ts switch to Go REST
Contract: /api/admin/v1/ai-models, /ai-tools, /ai-prompts
```

P2：Agent + knowledge core。

```text
Go modules: aiagent, aiknowledge
Tables: ai_agents, ai_agent_scenes, ai_assistant_tools, ai_agent_knowledge_bases, ai_knowledge_bases/documents/chunks
Frontend: agents/knowledge pages switch to Go REST
Important decision: scene dict must not include retired goods/cine scenes
```

P3：Conversation/message read and chat runtime。

```text
Go modules: aiconversation, aimessage, airuntime
Tables: ai_conversations, ai_messages, ai_runs, ai_run_steps
Runtime: request creates run, worker executes model/tool/RAG, final truth writes DB
Realtime: stream deltas over existing WebSocket envelope, not SSE
```

P4：Run monitor and timeout worker。

```text
Go modules: airun
Cron: ai_run_timeout -> ai:run-timeout:v1
Frontend: runs page switch to Go REST
Smoke: read-only runs/stats plus timeout registry gate
```

P5：PHP AI decommission gate。

```text
No src/api/ai/* legacyRequest remains.
No active cron_task handler starts with app\\process\\Ai.
No active AI menu points to a missing Go route.
No core AI contract is marked implemented without tests and smoke evidence.
```

## Verification matrix

```text
DB prune verification: targeted SQL above.
Backend static verification: rg goods_tts|cine_keyframes in admin_back_go/internal docs/contracts.
Frontend static verification: rg ai_goods|ai_cine|/ai/goods|/ai/cine|src/api/ai/goods|src/api/ai/cine.
Frontend type verification: npx vue-tsc -b --pretty false.
Frontend targeted tests: npx vitest run tests/shared/ai/agent-helpers.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts.
Backend verification: go test -p=1 ./... and go vet -p=1 ./... after enum/docs changes.
Smoke after cache clear: users/init menu must not return /ai/goods or /ai/cine; /ai/models and /ai/chat must still be present for authorized role.
```

## Self-review

- Scope is narrow enough for one implementation plan: Phase 0 prune only; Go AI runtime migration is a roadmap, not mixed into deletion.
- No placeholder requirement remains: every deleted/retained table, menu path, scene, folder, and verification query is explicit.
- Compatibility rule is explicit: history tables stay, scene/product modules retire, cache cleanup is outside this migration by user instruction.
