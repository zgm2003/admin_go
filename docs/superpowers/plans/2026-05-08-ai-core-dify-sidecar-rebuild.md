# AI Core Dify Sidecar Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the whole AI module around `admin_go + Dify sidecar + Go AIEngine adapter`, replacing the deterministic fake runtime with a real engine boundary while preserving admin_go RBAC, audit, REST, WebSocket, and Vue product ownership.

**Architecture:** Keep `admin_back_go` as a Gin modular monolith. Add `internal/platform/ai` as the only engine boundary, implement `DifyEngine` behind it, rebuild local AI tables as admin_go-owned mirror/control tables, and adapt existing Vue AI pages through typed `/api/admin/v1/*` clients. Dify is a sidecar AI engine, not the admin backend.

**Tech Stack:** Go toolchain from `admin_back_go/go.mod`, Gin, GORM/MySQL, existing secretbox/VAULT_KEY, existing taskqueue/worker, existing realtime Publisher/WebSocket envelope, Vue 3 + TypeScript + Element Plus + Vitest, Dify Service API.

---


## Current checkpoint before continuing on 2026-05-09

Do not restart from Task 1. Current repo evidence says Task 1-12 are materially implemented in the dirty working tree for the AI slice. The previous backend mismatch is fixed: `aiconversation` now uses `ai_conversations.app_id` and joins `ai_apps`, with `agent_id` only as an explicit legacy alias. Vue typed clients/pages for the six-product surface are also present. The remaining hard work is final verification, optional live Dify-enabled smoke, and a separate full-smoke maintenance issue caused by stale non-AI payment/wallet probes.

```text
Current green checks on 2026-05-09:
- go test ./internal/platform/ai ./internal/platform/ai/dify ./internal/module/aiengine ./internal/module/aiapp ./internal/module/aiknowledgemap ./internal/module/aitoolmap ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
- PowerShell parser check for admin_back_go/scripts/full-admin-smoke.ps1 => ps-parse-ok
- go test ./internal/module/aiconversation -count=1
- rg -n "ai_agents|c\.agent_id|column:agent_id|ActiveAgentExists|AgentName\(" internal/module/aiconversation internal/server/router_test.go -S => no active aiconversation runtime residue
- go test ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1

Already fixed:
- worker.go no longer redeclares aiChatEngineFactory; the single package-level factory is in app.go.
- airun reads the new app/engine/event schema and keeps agent_id/agent_name only as legacy aliases.
- aiconversation reads/writes app_id, validates active ai_apps, and emits app_id/app_name while retaining agent_id/agent_name as legacy aliases.
- server/router.go, bootstrap/app.go, and bootstrap/route_meta.go no longer mount or initialize old aimodel/aitool/aiprompt/aiagent/aiknowledge runtime.
- frontend has new typed clients: engineConnections.ts, apps.ts, knowledgeMaps.ts, toolMaps.ts.
- frontend removed old models/agents/prompts API/page surface and added providers/apps pages.

Resolved mismatch from plan/spec review:
- `internal/module/aiconversation` previously used `ai_conversations.agent_id` and joined `ai_agents`. It now aligns with the rebuild migration's `ai_conversations.app_id` schema and active `ai_apps` table.
- `aimessage` only joins `ai_conversations` by id/user ownership and does not need an app rename beyond tests/contracts.
- old AI routes are now retired from active runtime; they may appear only in backup/rollback/historical docs or negative route tests.
```

Immediate execution order from this checkpoint:

```text
1. Do not touch unrelated payment dirty files.
2. Keep Task 12 AI changes as the acceptance baseline: production fake provider removed, AI smoke gates rewritten, active docs updated.
3. If continuing execution, run the final backend/frontend verification commands from Task 12 Step 6/7.
4. Run full smoke only when local admin runtime and smoke credentials are available.
5. If full smoke fails at old payment/wallet paths, fix or classify that smoke maintenance separately; do not reopen the AI architecture.
6. Run optional Dify-enabled probe only when a configured sidecar app exists.
```

## Master rules

```text
No Vue -> Dify direct calls.
No Dify/OpenAI/Eino imports inside internal/module/*.
No plaintext API key in REST response, OperationLog, browser storage, console logs, or smoke output.
No silent production fallback to deterministic provider.
No schema drop without backup artifact or backup tables.
Keep browser realtime event names ai.response.*.v1.
Keep route -> handler -> service -> repository -> model in modules.
Do not add a fake "model provider" product page in phase one; model/prompt config lives in Dify app/workflow and local ai_apps snapshots.
Do not use map[string]any in module request/response DTOs or Vue types; use json.RawMessage/typed structs/Record<string, unknown> only at explicit external boundaries.
```

## Repository boundaries

```text
E:\admin_go                 # root docs repo: docs/*
E:\admin_go\admin_back_go   # backend repo: Go code, backend migrations, backend smoke
E:\admin_go\admin_front_ts  # frontend repo: Vue code and frontend tests
```

Do not run a root-level `git add admin_back_go/...` or `git add admin_front_ts/...`; the root repo does not track those nested repositories. Commit examples must be split by repo with `git -C E:\admin_go\admin_back_go ...`, `git -C E:\admin_go\admin_front_ts ...`, or root `git -C E:\admin_go ...`.

## File map

### Create

```text
admin_back_go/database/migrations/20260508_ai_core_backup.sql
admin_back_go/database/migrations/20260508_ai_core_rebuild.sql
admin_back_go/database/migrations/20260508_ai_core_rollback.sql

admin_back_go/internal/platform/ai/types.go
admin_back_go/internal/platform/ai/errors.go
admin_back_go/internal/platform/ai/fake.go
admin_back_go/internal/platform/ai/fake_test.go
admin_back_go/internal/platform/ai/dify/client.go
admin_back_go/internal/platform/ai/dify/client_test.go
admin_back_go/internal/platform/ai/dify/stream.go
admin_back_go/internal/platform/ai/dify/stream_test.go

admin_back_go/internal/module/aiengine/*
admin_back_go/internal/module/aiapp/*
admin_back_go/internal/module/aiknowledgemap/*
admin_back_go/internal/module/aitoolmap/*

admin_front_ts/src/api/ai/engineConnections.ts
admin_front_ts/src/api/ai/apps.ts
admin_front_ts/src/api/ai/knowledgeMaps.ts
admin_front_ts/src/api/ai/toolMaps.ts
admin_front_ts/tests/shared/ai/ai-engine-connection-api.test.ts
admin_front_ts/tests/shared/ai/ai-app-api.test.ts
admin_front_ts/tests/shared/ai/ai-knowledge-map-api.test.ts
admin_front_ts/tests/shared/ai/ai-tool-map-api.test.ts
admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts
```

### Modify

```text
admin_back_go/internal/config/config.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/module/aichat/dto.go
admin_back_go/internal/module/aichat/repository.go
admin_back_go/internal/module/aichat/service.go
admin_back_go/internal/module/aichat/service_test.go
admin_back_go/internal/module/aichat/events.go
admin_back_go/internal/module/aichat/events_test.go
admin_back_go/internal/module/aiconversation/*
admin_back_go/internal/module/airun/*
admin_back_go/scripts/full-admin-smoke.ps1

admin_front_ts/src/api/ai/chat.ts
admin_front_ts/src/api/ai/conversations.ts
admin_front_ts/src/api/ai/messages.ts
admin_front_ts/src/api/ai/runs.ts
admin_front_ts/src/views/Main/ai/chat/index.vue
admin_front_ts/src/views/Main/ai/runs/index.vue
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts

admin_back_go/docs/architecture.md
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
```

---

## Task 1: Schema backup, rebuild, and rollback SQL

**Files:**
- Create: `admin_back_go/database/migrations/20260508_ai_core_backup.sql`
- Create: `admin_back_go/database/migrations/20260508_ai_core_rebuild.sql`
- Create: `admin_back_go/database/migrations/20260508_ai_core_rollback.sql`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Write the backup SQL**

Create `20260508_ai_core_backup.sql`. It must not drop anything.

```sql
CREATE TABLE IF NOT EXISTS ai_models_backup_20260508 AS SELECT * FROM ai_models;
CREATE TABLE IF NOT EXISTS ai_tools_backup_20260508 AS SELECT * FROM ai_tools;
CREATE TABLE IF NOT EXISTS ai_prompts_backup_20260508 AS SELECT * FROM ai_prompts;
CREATE TABLE IF NOT EXISTS ai_prompt_backup_20260508 AS SELECT * FROM ai_prompt;
CREATE TABLE IF NOT EXISTS ai_agents_backup_20260508 AS SELECT * FROM ai_agents;
CREATE TABLE IF NOT EXISTS ai_agent_scenes_backup_20260508 AS SELECT * FROM ai_agent_scenes;
CREATE TABLE IF NOT EXISTS ai_assistant_tools_backup_20260508 AS SELECT * FROM ai_assistant_tools;
CREATE TABLE IF NOT EXISTS ai_agent_knowledge_bases_backup_20260508 AS SELECT * FROM ai_agent_knowledge_bases;
CREATE TABLE IF NOT EXISTS ai_knowledge_bases_backup_20260508 AS SELECT * FROM ai_knowledge_bases;
CREATE TABLE IF NOT EXISTS ai_knowledge_documents_backup_20260508 AS SELECT * FROM ai_knowledge_documents;
CREATE TABLE IF NOT EXISTS ai_knowledge_chunks_backup_20260508 AS SELECT * FROM ai_knowledge_chunks;
CREATE TABLE IF NOT EXISTS ai_conversations_backup_20260508 AS SELECT * FROM ai_conversations;
CREATE TABLE IF NOT EXISTS ai_messages_backup_20260508 AS SELECT * FROM ai_messages;
CREATE TABLE IF NOT EXISTS ai_runs_backup_20260508 AS SELECT * FROM ai_runs;
CREATE TABLE IF NOT EXISTS ai_run_steps_backup_20260508 AS SELECT * FROM ai_run_steps;

CREATE TABLE IF NOT EXISTS ai_permissions_backup_20260508 AS
SELECT *
FROM permissions
WHERE platform = 'admin'
  AND (
      path = '/ai'
      OR path LIKE '/ai/%'
      OR component = 'ai'
      OR component LIKE 'ai/%'
      OR i18n_key = 'menu.ai'
      OR i18n_key LIKE 'menu.ai\_%'
      OR code LIKE 'ai\_%'
  );

CREATE TABLE IF NOT EXISTS ai_role_permissions_backup_20260508 AS
SELECT rp.*
FROM role_permissions rp
JOIN permissions p ON p.id = rp.permission_id
WHERE p.platform = 'admin'
  AND (
      p.path = '/ai'
      OR p.path LIKE '/ai/%'
      OR p.component = 'ai'
      OR p.component LIKE 'ai/%'
      OR p.i18n_key = 'menu.ai'
      OR p.i18n_key LIKE 'menu.ai\_%'
      OR p.code LIKE 'ai\_%'
  );
```

- [ ] **Step 2: Write the rebuild SQL**

Create `20260508_ai_core_rebuild.sql`. Use `1=deleted`, `2=active` for `is_del`.

```sql
DROP TABLE IF EXISTS ai_models;
DROP TABLE IF EXISTS ai_tools;
DROP TABLE IF EXISTS ai_prompts;
DROP TABLE IF EXISTS ai_prompt;
DROP TABLE IF EXISTS ai_agents;
DROP TABLE IF EXISTS ai_agent_scenes;
DROP TABLE IF EXISTS ai_assistant_tools;
DROP TABLE IF EXISTS ai_agent_knowledge_bases;
DROP TABLE IF EXISTS ai_knowledge_bases;
DROP TABLE IF EXISTS ai_knowledge_documents;
DROP TABLE IF EXISTS ai_knowledge_chunks;
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS ai_messages;
DROP TABLE IF EXISTS ai_runs;
DROP TABLE IF EXISTS ai_run_steps;

CREATE TABLE ai_engine_connections (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(128) NOT NULL,
  engine_type VARCHAR(32) NOT NULL,
  base_url VARCHAR(512) NOT NULL,
  api_key_enc TEXT NULL,
  workspace_id VARCHAR(128) NOT NULL DEFAULT '',
  config_json JSON NULL,
  health_status VARCHAR(32) NOT NULL DEFAULT 'unknown',
  last_checked_at DATETIME NULL,
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_engine_connections_type_name (engine_type, name, is_del),
  KEY idx_ai_engine_connections_status (status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_apps (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  engine_connection_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(128) NOT NULL,
  code VARCHAR(128) NOT NULL,
  app_type VARCHAR(32) NOT NULL,
  engine_app_id VARCHAR(128) NOT NULL DEFAULT '',
  engine_app_api_key_enc TEXT NULL,
  default_response_mode VARCHAR(32) NOT NULL DEFAULT 'streaming',
  runtime_config_json JSON NULL,
  model_snapshot_json JSON NULL,
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_apps_code (code, is_del),
  KEY idx_ai_apps_connection (engine_connection_id, status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_app_bindings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  app_id BIGINT UNSIGNED NOT NULL,
  bind_type VARCHAR(32) NOT NULL,
  bind_key VARCHAR(128) NOT NULL,
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_app_bindings_key (app_id, bind_type, bind_key, is_del),
  KEY idx_ai_app_bindings_scope (bind_type, bind_key, status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_conversations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  app_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL DEFAULT '',
  engine_conversation_id VARCHAR(128) NOT NULL DEFAULT '',
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  last_message_at DATETIME NULL,
  meta_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ai_conversations_user (user_id, app_id, status, is_del),
  KEY idx_ai_conversations_engine (engine_conversation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  run_id BIGINT UNSIGNED NULL,
  user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
  role VARCHAR(32) NOT NULL,
  content_type VARCHAR(32) NOT NULL DEFAULT 'text',
  content LONGTEXT NOT NULL,
  engine_message_id VARCHAR(128) NOT NULL DEFAULT '',
  token_input INT NOT NULL DEFAULT 0,
  token_output INT NOT NULL DEFAULT 0,
  feedback TINYINT NULL,
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  meta_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ai_messages_conversation (conversation_id, id, is_del),
  KEY idx_ai_messages_run (run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_runs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_uid VARCHAR(64) NOT NULL,
  app_id BIGINT UNSIGNED NOT NULL,
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  engine_connection_id BIGINT UNSIGNED NOT NULL,
  engine_task_id VARCHAR(128) NOT NULL DEFAULT '',
  engine_run_id VARCHAR(128) NOT NULL DEFAULT '',
  request_id VARCHAR(128) NOT NULL DEFAULT '',
  status VARCHAR(32) NOT NULL,
  input_snapshot_json JSON NULL,
  output_snapshot_json JSON NULL,
  usage_json JSON NULL,
  prompt_tokens INT NOT NULL DEFAULT 0,
  completion_tokens INT NOT NULL DEFAULT 0,
  total_tokens INT NOT NULL DEFAULT 0,
  cost DECIMAL(18,6) NOT NULL DEFAULT 0,
  latency_ms INT NOT NULL DEFAULT 0,
  error_code VARCHAR(64) NOT NULL DEFAULT '',
  error_message VARCHAR(1024) NOT NULL DEFAULT '',
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  canceled_at DATETIME NULL,
  is_del TINYINT NOT NULL DEFAULT 2,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_runs_uid (run_uid),
  KEY idx_ai_runs_user (user_id, status, created_at),
  KEY idx_ai_runs_engine_task (engine_task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_run_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_id BIGINT UNSIGNED NOT NULL,
  seq BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  delta_text TEXT NULL,
  payload_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_run_events_seq (run_id, seq),
  KEY idx_ai_run_events_type (event_type, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_knowledge_maps (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  engine_connection_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(128) NOT NULL,
  code VARCHAR(128) NOT NULL,
  engine_dataset_id VARCHAR(128) NOT NULL DEFAULT '',
  visibility VARCHAR(32) NOT NULL DEFAULT 'private',
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  meta_json JSON NULL,
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_knowledge_maps_code (code, is_del),
  KEY idx_ai_knowledge_maps_engine (engine_connection_id, status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_knowledge_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  knowledge_map_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  engine_document_id VARCHAR(128) NOT NULL DEFAULT '',
  source_type VARCHAR(32) NOT NULL,
  source_ref VARCHAR(512) NOT NULL DEFAULT '',
  indexing_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  error_message VARCHAR(1024) NOT NULL DEFAULT '',
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  meta_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ai_knowledge_documents_map (knowledge_map_id, status, is_del),
  KEY idx_ai_knowledge_documents_engine (engine_document_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_tool_maps (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  engine_connection_id BIGINT UNSIGNED NOT NULL,
  app_id BIGINT UNSIGNED NULL,
  name VARCHAR(128) NOT NULL,
  code VARCHAR(128) NOT NULL,
  tool_type VARCHAR(32) NOT NULL,
  engine_tool_id VARCHAR(128) NOT NULL DEFAULT '',
  permission_code VARCHAR(128) NOT NULL DEFAULT '',
  risk_level VARCHAR(32) NOT NULL DEFAULT 'low',
  config_json JSON NULL,
  status TINYINT NOT NULL DEFAULT 1,
  is_del TINYINT NOT NULL DEFAULT 2,
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_tool_maps_code (code, is_del),
  KEY idx_ai_tool_maps_app (app_id, status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_usage_daily (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usage_date DATE NOT NULL,
  app_id BIGINT UNSIGNED NOT NULL,
  engine_connection_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
  run_count INT NOT NULL DEFAULT 0,
  fail_count INT NOT NULL DEFAULT 0,
  prompt_tokens BIGINT NOT NULL DEFAULT 0,
  completion_tokens BIGINT NOT NULL DEFAULT 0,
  total_tokens BIGINT NOT NULL DEFAULT 0,
  cost DECIMAL(18,6) NOT NULL DEFAULT 0,
  latency_ms_total BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_usage_daily_scope (usage_date, app_id, engine_connection_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 3: Write rollback SQL**

Create `20260508_ai_core_rollback.sql`. It must restore from backup tables and must not delete Dify sidecar data.

```sql
DROP TABLE IF EXISTS ai_engine_connections;
DROP TABLE IF EXISTS ai_apps;
DROP TABLE IF EXISTS ai_app_bindings;
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS ai_messages;
DROP TABLE IF EXISTS ai_runs;
DROP TABLE IF EXISTS ai_run_events;
DROP TABLE IF EXISTS ai_knowledge_maps;
DROP TABLE IF EXISTS ai_knowledge_documents;
DROP TABLE IF EXISTS ai_tool_maps;
DROP TABLE IF EXISTS ai_usage_daily;

CREATE TABLE ai_models AS SELECT * FROM ai_models_backup_20260508;
CREATE TABLE ai_tools AS SELECT * FROM ai_tools_backup_20260508;
CREATE TABLE ai_prompts AS SELECT * FROM ai_prompts_backup_20260508;
CREATE TABLE ai_prompt AS SELECT * FROM ai_prompt_backup_20260508;
CREATE TABLE ai_agents AS SELECT * FROM ai_agents_backup_20260508;
CREATE TABLE ai_agent_scenes AS SELECT * FROM ai_agent_scenes_backup_20260508;
CREATE TABLE ai_assistant_tools AS SELECT * FROM ai_assistant_tools_backup_20260508;
CREATE TABLE ai_agent_knowledge_bases AS SELECT * FROM ai_agent_knowledge_bases_backup_20260508;
CREATE TABLE ai_knowledge_bases AS SELECT * FROM ai_knowledge_bases_backup_20260508;
CREATE TABLE ai_knowledge_documents AS SELECT * FROM ai_knowledge_documents_backup_20260508;
CREATE TABLE ai_knowledge_chunks AS SELECT * FROM ai_knowledge_chunks_backup_20260508;
CREATE TABLE ai_conversations AS SELECT * FROM ai_conversations_backup_20260508;
CREATE TABLE ai_messages AS SELECT * FROM ai_messages_backup_20260508;
CREATE TABLE ai_runs AS SELECT * FROM ai_runs_backup_20260508;
CREATE TABLE ai_run_steps AS SELECT * FROM ai_run_steps_backup_20260508;

DELETE rp FROM role_permissions rp
JOIN permissions p ON p.id = rp.permission_id
WHERE p.platform = 'admin'
  AND (
      p.path = '/ai'
      OR p.path LIKE '/ai/%'
      OR p.component = 'ai'
      OR p.component LIKE 'ai/%'
      OR p.i18n_key = 'menu.ai'
      OR p.i18n_key LIKE 'menu.ai\_%'
      OR p.code LIKE 'ai\_%'
  );

DELETE FROM permissions
WHERE platform = 'admin'
  AND (
      path = '/ai'
      OR path LIKE '/ai/%'
      OR component = 'ai'
      OR component LIKE 'ai/%'
      OR i18n_key = 'menu.ai'
      OR i18n_key LIKE 'menu.ai\_%'
      OR code LIKE 'ai\_%'
  );

INSERT INTO permissions SELECT * FROM ai_permissions_backup_20260508;
INSERT INTO role_permissions SELECT * FROM ai_role_permissions_backup_20260508;
```

- [ ] **Step 4: Contract update before code**

Add a `AI Core Dify Sidecar Rebuild` section to `docs/contracts/admin-api-v1.md`. Mark status honestly: initially `planned`; after Task 8/9 backend verification, update it to `partially implemented` and name Vue adaptation as pending. List the endpoints from Tasks 4-12, including the Task 10 `ai-conversations` app_id cleanup and Task 11 Vue contract clients.

- [ ] **Step 5: Verify SQL text**

```powershell
cd E:\admin_go\admin_back_go
Get-Content .\database\migrations\20260508_ai_core_rebuild.sql | Select-String -Pattern "CREATE TABLE ai_engine_connections|CREATE TABLE ai_run_events|CREATE TABLE ai_usage_daily"
```

Expected: all three lines are printed.

- [ ] **Step 6: Commit task 1**

```powershell
git -C E:\admin_go\admin_back_go add database/migrations/20260508_ai_core_backup.sql database/migrations/20260508_ai_core_rebuild.sql database/migrations/20260508_ai_core_rollback.sql
git -C E:\admin_go\admin_back_go commit -m "feat: add ai core schema rebuild migrations"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: define ai core api contract"
```

---

## Task 2: Add `internal/platform/ai` interface and fake engine

**Files:**
- Create: `admin_back_go/internal/platform/ai/types.go`
- Create: `admin_back_go/internal/platform/ai/errors.go`
- Create: `admin_back_go/internal/platform/ai/fake.go`
- Create: `admin_back_go/internal/platform/ai/fake_test.go`

- [ ] **Step 1: Add core types**

Create `types.go`:

```go
package ai

import (
	"context"
	"encoding/json"
)

type EngineType string

const (
	EngineTypeDify   EngineType = "dify"
	EngineTypeEino   EngineType = "eino"
	EngineTypeDirect EngineType = "direct"
)

type TestConnectionInput struct {
	EngineType EngineType
	BaseURL    string
	APIKey     string
	TimeoutMs  int
}

type TestConnectionResult struct {
	OK        bool
	Status    string
	LatencyMs int
	Message   string
}

type ChatInput struct {
	AppID                uint64
	RunID                uint64
	UserID               uint64
	UserKey              string
	Content              string
	ConversationEngineID string
	InputsJSON           json.RawMessage
	FilesJSON            json.RawMessage
}

type ChatResult struct {
	EngineConversationID string
	EngineMessageID      string
	EngineTaskID         string
	Answer               string
	PromptTokens         int
	CompletionTokens     int
	TotalTokens          int
	Cost                 float64
	LatencyMs            int
}

type StopChatInput struct {
	EngineTaskID string
	UserKey      string
}

type KnowledgeSyncInput struct {
	DatasetID string
	Document  KnowledgeDocument
}

type KnowledgeDocument struct {
	Name      string
	Text      string
	SourceRef string
}

type KnowledgeSyncResult struct {
	EngineDatasetID  string
	EngineDocumentID string
	EngineBatchID    string
	IndexingStatus   string
}

type Event struct {
	Type        string
	DeltaText   string
	PayloadJSON json.RawMessage
}

type EventSink interface {
	Emit(ctx context.Context, event Event) error
}

type Engine interface {
	TestConnection(ctx context.Context, input TestConnectionInput) (*TestConnectionResult, error)
	StreamChat(ctx context.Context, input ChatInput, sink EventSink) (*ChatResult, error)
	StopChat(ctx context.Context, input StopChatInput) error
	SyncKnowledge(ctx context.Context, input KnowledgeSyncInput) (*KnowledgeSyncResult, error)
}
```

- [ ] **Step 2: Add categorized errors**

Create `errors.go`:

```go
package ai

import "errors"

var (
	ErrEngineDisabled   = errors.New("ai engine disabled")
	ErrInvalidConfig    = errors.New("ai engine invalid config")
	ErrUnauthorized     = errors.New("ai engine unauthorized")
	ErrRateLimited      = errors.New("ai engine rate limited")
	ErrUpstreamTimeout  = errors.New("ai engine upstream timeout")
	ErrUpstreamRejected = errors.New("ai engine upstream rejected")
)
```

- [ ] **Step 3: Add fake engine for tests only**

Create `fake.go`:

```go
package ai

import "context"

type FakeEngine struct {
	Answer string
}

func (f FakeEngine) TestConnection(ctx context.Context, input TestConnectionInput) (*TestConnectionResult, error) {
	return &TestConnectionResult{OK: true, Status: "ok", Message: "fake engine ready"}, nil
}

func (f FakeEngine) StreamChat(ctx context.Context, input ChatInput, sink EventSink) (*ChatResult, error) {
	answer := f.Answer
	if answer == "" {
		answer = "fake answer"
	}
	if err := sink.Emit(ctx, Event{Type: "delta", DeltaText: answer}); err != nil {
		return nil, err
	}
	return &ChatResult{Answer: answer, EngineConversationID: "fake-conversation", EngineMessageID: "fake-message", EngineTaskID: "fake-task"}, nil
}

func (f FakeEngine) StopChat(ctx context.Context, input StopChatInput) error { return nil }

func (f FakeEngine) SyncKnowledge(ctx context.Context, input KnowledgeSyncInput) (*KnowledgeSyncResult, error) {
	return &KnowledgeSyncResult{EngineDatasetID: input.DatasetID, EngineDocumentID: "fake-document", EngineBatchID: "fake-batch", IndexingStatus: "completed"}, nil
}
```

- [ ] **Step 4: Add tests and run**

Create `fake_test.go`:

```go
package ai

import (
	"context"
	"testing"
)

type captureSink struct{ events []Event }

func (s *captureSink) Emit(ctx context.Context, event Event) error {
	s.events = append(s.events, event)
	return nil
}

func TestFakeEngineStreamChatEmitsDelta(t *testing.T) {
	sink := &captureSink{}
	result, err := FakeEngine{Answer: "hello"}.StreamChat(context.Background(), ChatInput{Content: "hi", UserKey: "admin:1"}, sink)
	if err != nil { t.Fatalf("StreamChat error: %v", err) }
	if result.Answer != "hello" { t.Fatalf("answer mismatch: %q", result.Answer) }
	if len(sink.events) != 1 || sink.events[0].DeltaText != "hello" { t.Fatalf("events mismatch: %#v", sink.events) }
}
```

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai -count=1
```

Expected: PASS.

- [ ] **Step 5: Commit task 2**

```powershell
git -C E:\admin_go\admin_back_go add internal/platform/ai
git -C E:\admin_go\admin_back_go commit -m "feat: add ai engine platform boundary"
```

---

## Task 3: Implement Dify client adapter

**Files:**
- Create: `admin_back_go/internal/platform/ai/dify/client.go`
- Create: `admin_back_go/internal/platform/ai/dify/stream.go`
- Create: `admin_back_go/internal/platform/ai/dify/client_test.go`
- Create: `admin_back_go/internal/platform/ai/dify/stream_test.go`

- [ ] **Step 1: Add Dify SSE parser tests**

Create `stream_test.go`:

```go
package dify

import (
	"strings"
	"testing"
)

func TestDecodeStreamEvents(t *testing.T) {
	input := strings.NewReader("data: {\"event\":\"message\",\"task_id\":\"task-1\",\"message_id\":\"msg-1\",\"conversation_id\":\"conv-1\",\"answer\":\"hello\"}\n\n" +
		"data: {\"event\":\"message_end\",\"metadata\":{\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}}\n\n")
	events, err := DecodeStreamEvents(input)
	if err != nil { t.Fatalf("DecodeStreamEvents error: %v", err) }
	if len(events) != 2 { t.Fatalf("event count=%d", len(events)) }
	if events[0].Answer != "hello" || events[0].TaskID != "task-1" || events[0].MessageID != "msg-1" || events[0].ConversationID != "conv-1" { t.Fatalf("message event mismatch: %#v", events[0]) }
	if events[1].Usage.TotalTokens != 5 { t.Fatalf("usage mismatch: %#v", events[1].Usage) }
}
```

- [ ] **Step 2: Implement stream parser**

Create `stream.go`:

```go
package dify

import (
	"bufio"
	"encoding/json"
	"io"
	"strings"
)

type Usage struct {
	PromptTokens     int     `json:"prompt_tokens"`
	CompletionTokens int     `json:"completion_tokens"`
	TotalTokens      int     `json:"total_tokens"`
	TotalPrice       float64 `json:"total_price"`
}

type StreamEvent struct {
	Event          string `json:"event"`
	TaskID         string `json:"task_id"`
	MessageID      string `json:"message_id"`
	ConversationID string `json:"conversation_id"`
	Answer         string `json:"answer"`
	Metadata       struct { Usage Usage `json:"usage"` } `json:"metadata"`
	Usage          Usage
}

func DecodeStreamEvents(r io.Reader) ([]StreamEvent, error) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	var events []StreamEvent
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "data:") { continue }
		payload := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if payload == "" || payload == "[DONE]" { continue }
		var event StreamEvent
		if err := json.Unmarshal([]byte(payload), &event); err != nil { return nil, err }
		if event.Usage.TotalTokens == 0 { event.Usage = event.Metadata.Usage }
		events = append(events, event)
	}
	if err := scanner.Err(); err != nil { return nil, err }
	return events, nil
}
```

- [ ] **Step 3: Add client tests**

Create `client_test.go` with `httptest.Server` cases:

```text
POST /chat-messages receives Authorization: Bearer test-key.
request body contains response_mode=streaming, query, user, conversation_id.
stream result maps task_id/message_id/conversation_id/usage.
POST /chat-messages/{task_id}/stop sends the same user key.
```

- [ ] **Step 4: Implement `client.go`**

Implementation must:

```text
Use http.Client with context timeout.
Call POST /chat-messages for StreamChat.
Call POST /chat-messages/{task_id}/stop for StopChat.
Set Authorization: Bearer <api key>.
Never log api key.
Map Dify message/message_end/error events into platform ai.Event and ai.ChatResult.
```


- [ ] **Step 6: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai ./internal/platform/ai/dify -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit task 3**

```powershell
git -C E:\admin_go\admin_back_go add internal/platform/ai/dify
git -C E:\admin_go\admin_back_go commit -m "feat: add dify ai engine adapter"
```

---

## Task 4: Add engine connection management module

**Files:**
- Create: `admin_back_go/internal/module/aiengine/*`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Define request/response contracts**

Use these request shapes:

```go
type CreateRequest struct {
	Name        string `json:"name" binding:"required,max=128"`
	EngineType  string `json:"engine_type" binding:"required,oneof=dify direct eino ragflow"`
	BaseURL     string `json:"base_url" binding:"required,url,max=512"`
	APIKey      string `json:"api_key" binding:"omitempty,max=4096"`
	WorkspaceID string `json:"workspace_id" binding:"omitempty,max=128"`
	Status      int    `json:"status" binding:"required,oneof=1 2"`
}

type UpdateRequest = CreateRequest

type StatusRequest struct {
	Status int `json:"status" binding:"required,oneof=1 2"`
}
```

Response must use a masked field:

```go
type ConnectionDTO struct {
	ID           uint64 `json:"id"`
	Name         string `json:"name"`
	EngineType   string `json:"engine_type"`
	BaseURL      string `json:"base_url"`
	APIKeyMasked string `json:"api_key_masked"`
	HealthStatus string `json:"health_status"`
	LastCheckedAt string `json:"last_checked_at"`
	Status       int    `json:"status"`
}
```

- [ ] **Step 2: Implement repository/service/handler**

Rules:

```text
repository owns ai_engine_connections access only.
service encrypts APIKey with existing secretbox/VAULT_KEY pattern.
service decrypts only for connection test or engine construction.
handler never sees plaintext API key after request binding.
```

- [ ] **Step 3: Add routes**

```text
GET    /api/admin/v1/ai-engine-connections/page-init
GET    /api/admin/v1/ai-engine-connections
POST   /api/admin/v1/ai-engine-connections
PUT    /api/admin/v1/ai-engine-connections/:id
PATCH  /api/admin/v1/ai-engine-connections/:id/status
POST   /api/admin/v1/ai-engine-connections/:id/test
DELETE /api/admin/v1/ai-engine-connections/:id
```

- [ ] **Step 4: OperationLog metadata**

Add route metadata with module `ai_engine_connection`. Mutating routes must mask `api_key`, `apiKey`, `api_key_enc`, and Authorization-like fields.


- [ ] **Step 6: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiengine ./internal/server ./internal/bootstrap -count=1
```

Expected: PASS; tests prove no plaintext API key appears in response payloads.

- [ ] **Step 6: Commit task 4**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiengine internal/server/router.go internal/bootstrap/app.go internal/bootstrap/route_meta.go internal/bootstrap/route_meta_test.go
git -C E:\admin_go\admin_back_go commit -m "feat: add ai engine connection management"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: update ai engine connection contract"
```

---

## Task 5: Add AI app and binding management module

**Files:**
- Create: `admin_back_go/internal/module/aiapp/*`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Define request contracts**

```go
type CreateRequest struct {
	EngineConnectionID  uint64         `json:"engine_connection_id" binding:"required,gt=0"`
	Name                string         `json:"name" binding:"required,max=128"`
	Code                string         `json:"code" binding:"required,max=128"`
	AppType             string         `json:"app_type" binding:"required,oneof=chat workflow completion agent"`
	EngineAppID         string         `json:"engine_app_id" binding:"omitempty,max=128"`
	EngineAppAPIKey     string         `json:"engine_app_api_key" binding:"omitempty,max=4096"`
	DefaultResponseMode string         `json:"default_response_mode" binding:"required,oneof=streaming blocking"`
	RuntimeConfig       json.RawMessage `json:"runtime_config"`
	Status              int            `json:"status" binding:"required,oneof=1 2"`
}

type BindingRequest struct {
	BindType string `json:"bind_type" binding:"required,oneof=menu scene permission role user"`
	BindKey  string `json:"bind_key" binding:"required,max=128"`
	Sort     int    `json:"sort"`
	Status   int    `json:"status" binding:"required,oneof=1 2"`
}
```

`runtime_config` must be validated as a JSON object before storage. Store `{}` when omitted. Do not decode it into `map[string]any` in request/response DTOs.

- [ ] **Step 2: Implement app visibility**

Service must answer:

```text
Can current user see this app?
Which default app should chat page load?
Does app have active engine connection and app API key?
```

- [ ] **Step 3: Add routes**

```text
GET    /api/admin/v1/ai-apps/page-init
GET    /api/admin/v1/ai-apps
GET    /api/admin/v1/ai-apps/options
GET    /api/admin/v1/ai-apps/:id
POST   /api/admin/v1/ai-apps
PUT    /api/admin/v1/ai-apps/:id
PATCH  /api/admin/v1/ai-apps/:id/status
POST   /api/admin/v1/ai-apps/:id/test
DELETE /api/admin/v1/ai-apps/:id
GET    /api/admin/v1/ai-apps/:id/bindings
POST   /api/admin/v1/ai-apps/:id/bindings
DELETE /api/admin/v1/ai-app-bindings/:id
```



- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiapp -count=1
```

Expected:

```text
create rejects missing active engine connection.
response masks engine_app_api_key.
code is unique among active rows.
binding is unique on app_id + bind_type + bind_key.
current-user app options exclude disabled apps.
options endpoint returns only active visible apps for the current user.
```

- [ ] **Step 5: Commit task 5**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiapp internal/server/router.go internal/bootstrap/app.go
git -C E:\admin_go\admin_back_go commit -m "feat: add ai app mapping management"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: update ai app mapping contract"
```

---

## Task 6: Add knowledge map and document sync first slice

**Files:**
- Create: `admin_back_go/internal/module/aiknowledgemap/*`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Add routes**

```text
GET    /api/admin/v1/ai-knowledge-maps/page-init
GET    /api/admin/v1/ai-knowledge-maps
POST   /api/admin/v1/ai-knowledge-maps
PUT    /api/admin/v1/ai-knowledge-maps/:id
PATCH  /api/admin/v1/ai-knowledge-maps/:id/status
POST   /api/admin/v1/ai-knowledge-maps/:id/sync
DELETE /api/admin/v1/ai-knowledge-maps/:id
GET    /api/admin/v1/ai-knowledge-maps/:id/documents
POST   /api/admin/v1/ai-knowledge-maps/:id/documents
PATCH  /api/admin/v1/ai-knowledge-documents/:id/status
POST   /api/admin/v1/ai-knowledge-documents/:id/refresh-status
DELETE /api/admin/v1/ai-knowledge-documents/:id
```

- [ ] **Step 2: Implement first-slice behavior**

```text
Create map stores engine_dataset_id if linked.
Sync map calls Engine.SyncKnowledge only for active engine connections.
Create document supports source_type=text first.
file source_type stores source_ref but returns an explicit unsupported error for upload ingestion in this slice.
Refresh status reads Dify document/indexing status through platform adapter.
```



- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledgemap -count=1
```

Expected:

```text
text document create stores engine_document_id and indexing_status.
disabled map cannot sync.
Dify error stores error_message and returns code != 0.
list never returns raw engine credential.
```

- [ ] **Step 4: Commit task 6**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiknowledgemap internal/server/router.go internal/bootstrap/app.go
git -C E:\admin_go\admin_back_go commit -m "feat: add ai knowledge engine mapping"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: update ai knowledge mapping contract"
```

---

## Task 7: Add tool map module with safe execution boundary

**Files:**
- Create: `admin_back_go/internal/module/aitoolmap/*`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Add routes and enums**

```text
GET    /api/admin/v1/ai-tool-maps/page-init
GET    /api/admin/v1/ai-tool-maps
POST   /api/admin/v1/ai-tool-maps
PUT    /api/admin/v1/ai-tool-maps/:id
PATCH  /api/admin/v1/ai-tool-maps/:id/status
DELETE /api/admin/v1/ai-tool-maps/:id

tool_type: dify_tool / workflow_node / admin_action_gateway / http_reference
risk_level: low / medium / high
```

- [ ] **Step 2: Block arbitrary admin API execution**

Service rejects `tool_type=admin_action_gateway` unless `permission_code` is non-empty and matches an existing permission code. This slice stores maps only; it does not execute internal admin actions.



- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aitoolmap -count=1
```

Expected:

```text
create dify_tool with engine_tool_id succeeds.
create admin_action_gateway without permission_code fails.
status switch preserves config_json.
response never includes engine secrets.
```

- [ ] **Step 4: Commit task 7**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aitoolmap internal/server/router.go internal/bootstrap/app.go
git -C E:\admin_go\admin_back_go commit -m "feat: add ai tool mapping management"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: update ai tool mapping contract"
```

---

## Task 8: Switch chat runtime to AIEngine and persist run events, then fix bootstrap wiring

**Files:**
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/repository.go`
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/events.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] **Step 1: Delete production deterministic default**

Replace the current default `deterministicProvider{}` path with explicit engine resolution:

```text
load ai_apps by app_id
load ai_engine_connections by app.engine_connection_id
decrypt app/connection API key
construct platform ai.Engine by engine_type
return explicit config error when no active engine exists
```

Fake engine may remain only in tests. If `Provider` / `deterministicProvider` remains for old unit tests during this checkpoint, production constructors in `bootstrap` must not inject it, and final residue scan must show no production path can fake success.

- [ ] **Step 2: Add event sink backed by `ai_run_events`**

`aichat` service must create an `EventSink` that does both:

```text
insert ai_run_events with monotonic seq per run
publish ai.response.*.v1 through realtime.Publisher
```

- [ ] **Step 3: Preserve REST event catch-up**

`GET /api/admin/v1/ai-chat/runs/:run_id/events` must read `ai_run_events`, not reconstruct from `ai_run_steps`.

- [ ] **Step 4: Store engine IDs**

```text
ai_conversations.engine_conversation_id
ai_messages.engine_message_id
ai_runs.engine_task_id
ai_runs.engine_run_id where available
```



- [ ] **Step 5: Fix bootstrap engine factory duplication**

Keep exactly one package-level `aiChatEngineFactory` in `internal/bootstrap`. Prefer keeping the definition in `app.go` or moving it to a new focused `ai_engine_factory.go`; do not define it again in `worker.go`.

Historical compile failure that is already fixed in the current dirty tree:

```text
internal\bootstrap\worker.go:257:6: aiChatEngineFactory redeclared in this block
internal\bootstrap\app.go:407:6: other declaration of aiChatEngineFactory
```

If this failure reappears, apply the concrete fix below while keeping it in `app.go`:

```text
Delete from worker.go:
- type aiChatEngineFactory struct{}
- func (aiChatEngineFactory) NewEngine(...)

Then remove worker.go imports only used by that duplicate definition:
- platformai "admin_back_go/internal/platform/ai"
- "admin_back_go/internal/platform/ai/dify"
- time, if no longer used elsewhere
```

Do not rename the type in only one file; that just hides the duplicate instead of removing the bad ownership.

- [ ] **Step 6: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat ./internal/bootstrap -count=1
```

Expected:

```text
without active engine returns explicit error and writes failed run.
fake test engine emits persisted event and assistant message.
cancel calls Engine.StopChat when engine_task_id exists.
REST catch-up returns ordered ai_run_events.
```

- [ ] **Step 7: Commit task 8**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aichat internal/bootstrap/app.go internal/bootstrap/worker.go
git -C E:\admin_go\admin_back_go commit -m "feat: run ai chat through engine boundary"
```

---

## Task 9: Run monitor and usage aggregation

**Files:**
- Modify: `admin_back_go/internal/module/airun/*`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Move run monitor off old agent/step schema**

`airun` must stop using `ai_agents` and `ai_run_steps` as the primary monitor source. The new query source is:

```text
ai_runs r
LEFT JOIN ai_apps a ON a.id = r.app_id
LEFT JOIN ai_engine_connections e ON e.id = r.engine_connection_id
LEFT JOIN ai_conversations c ON c.id = r.conversation_id
LEFT JOIN users u ON u.id = r.user_id
LEFT JOIN ai_run_events ev ON ev.run_id = r.id for detail only
```

Required DTO direction:

```text
List filters: app_id, engine_connection_id, user_id, request_id, run_status, date range.
Page-init options: appArr from ai_apps, engineArr from ai_engine_connections.
Legacy response fields agent_id/agent_name may remain as aliases for app_id/app_name for one frontend pass, but new fields app_id/app_name must exist.
Detail response includes events [] ordered by seq; steps [] may remain empty or deprecated, but must not query ai_run_steps.
Stats by agent remains route-compatible but must be backed by app_id/app_name until frontend renames it.
```

- [ ] **Step 2: Add events to run detail**

`GET /api/admin/v1/ai-runs/:id` response must expose a flat detail compatible with existing handler plus durable events:

```ts
interface AiRunEventRow {
  id: number
  seq: number
  event_id: string
  event_type: string
  delta_text: string
  payload_json: Record<string, unknown>
  created_at: string
}

interface AiRunDetail {
  id: number
  request_id: string
  app_id: number
  app_name: string
  engine_connection_id: number
  engine_name: string
  user_message: AiMessageRow | null
  assistant_message: AiMessageRow | null
  events: AiRunEventRow[]
}
```

- [ ] **Step 3: Aggregate usage**

After a run completes, fails, times out, or is canceled, upsert `ai_usage_daily`. Current `aichat.MarkSuccess/MarkFailed` already starts this; finish cancel/timeout exactly-once behavior and expose reads through `airun`:

```text
usage_date = DATE(completed_at or created_at)
app_id
engine_connection_id
user_id
run_count += 1
fail_count += 1 only for failed/timeout/canceled
prompt_tokens/completion_tokens/total_tokens += run usage
cost += run cost
latency_ms_total += run latency
```



- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/airun ./internal/module/aichat -run "Usage|Detail|Events|Stats|Init|Cancel|Timeout" -count=1
```

Expected: PASS.

- [ ] **Step 5: Smoke update**

Update `full-admin-smoke.ps1`:

```text
Always probe ai-runs page-init/list/stats shape and assert no raw API key fields.
When DIFY_SMOKE_APP_ID is absent, verify chat start returns explicit config error, not deterministic success.
When DIFY_SMOKE_APP_ID is present, create one smoke run and assert engine_task_id or engine_message_id exists and events are persisted.
```

- [ ] **Step 6: Commit task 9**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/airun internal/module/aichat scripts/full-admin-smoke.ps1
git -C E:\admin_go\admin_back_go commit -m "feat: mirror ai run events and usage"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: update ai run event contract"
```

---


## Task 10: Realign current-user conversations from agent_id to app_id

**Files:**
- Modify: `admin_back_go/internal/module/aiconversation/model.go`
- Modify: `admin_back_go/internal/module/aiconversation/dto.go`
- Modify: `admin_back_go/internal/module/aiconversation/request.go`
- Modify: `admin_back_go/internal/module/aiconversation/handler.go`
- Modify: `admin_back_go/internal/module/aiconversation/repository.go`
- Modify: `admin_back_go/internal/module/aiconversation/service.go`
- Modify: `admin_back_go/internal/module/aiconversation/service_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Write/adjust service tests around app_id**

Update `admin_back_go/internal/module/aiconversation/service_test.go` so create/list/detail use `app_id` as the primary field and keep `agent_id` only as an alias in response compatibility checks.

Minimum assertions:

```go
func TestServiceCreateRequiresActiveApp(t *testing.T) {
    repo := &fakeRepository{activeApp: true}
    service := NewService(repo)

    id, appErr := service.Create(context.Background(), 7, MutationInput{AppID: 3, Title: "客服"})

    if appErr != nil || id == 0 {
        t.Fatalf("Create() appErr=%v id=%d", appErr, id)
    }
    if repo.created.AppID != 3 || repo.created.AgentID != 0 {
        t.Fatalf("created app_id=%d agent_id=%d", repo.created.AppID, repo.created.AgentID)
    }
}

func TestServiceCreateAcceptsLegacyAgentIDAsAppID(t *testing.T) {
    repo := &fakeRepository{activeApp: true}
    service := NewService(repo)

    _, appErr := service.Create(context.Background(), 7, MutationInput{AgentID: 9, Title: "legacy"})

    if appErr != nil {
        t.Fatalf("Create() appErr=%v", appErr)
    }
    if repo.created.AppID != 9 {
        t.Fatalf("legacy agent_id should map to app_id, got %d", repo.created.AppID)
    }
}
```

The fake repository should expose `ActiveAppExists(ctx, appID int64)`, not `ActiveAgentExists`.

- [ ] **Step 2: Change model and DTO ownership**

`model.go` must match the rebuild migration:

```go
type Conversation struct {
    ID            int64      `gorm:"column:id;primaryKey"`
    AppID         int64      `gorm:"column:app_id"`
    UserID        int64      `gorm:"column:user_id"`
    Title         string     `gorm:"column:title"`
    LastMessageAt *time.Time `gorm:"column:last_message_at"`
    Status        int        `gorm:"column:status"`
    IsDel         int        `gorm:"column:is_del"`
    CreatedAt     time.Time  `gorm:"column:created_at"`
    UpdatedAt     time.Time  `gorm:"column:updated_at"`
}
```

`dto.go` must expose `app_id` / `app_name` first and keep `agent_id` / `agent_name` as legacy aliases only:

```go
type ListQuery struct {
    UserID      int64
    CurrentPage int
    PageSize    int
    Status      *int
    AppID       *int64
    AgentID     *int64 // legacy alias for AppID during one Vue migration pass
    Title       string
}

type ListItem struct {
    ID            int64  `json:"id"`
    UserID        int64  `json:"user_id"`
    AppID         int64  `json:"app_id"`
    AppName       string `json:"app_name"`
    AgentID       int64  `json:"agent_id"`
    AgentName     string `json:"agent_name"`
    Title         string `json:"title"`
    LastMessageAt string `json:"last_message_at"`
    Status        int    `json:"status"`
    StatusName    string `json:"status_name"`
    CreatedAt     string `json:"created_at"`
    UpdatedAt     string `json:"updated_at"`
}

type MutationInput struct {
    AppID   int64
    AgentID int64 // legacy alias for AppID
    Title   string
    Status  int
}
```

- [ ] **Step 3: Change request structs and handler mapping**

`request.go` must accept both `app_id` and legacy `agent_id`, but service receives a normalized `MutationInput`:

```go
type listRequest struct {
    CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
    PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=50"`
    Status      *int   `form:"status" binding:"omitempty,oneof=1 2"`
    AppID       *int64 `form:"app_id" binding:"omitempty,min=1"`
    AgentID     *int64 `form:"agent_id" binding:"omitempty,min=1"`
    Title       string `form:"title" binding:"omitempty,max=100"`
}

type mutationRequest struct {
    AppID   int64  `json:"app_id" binding:"omitempty,min=1"`
    AgentID int64  `json:"agent_id" binding:"omitempty,min=1"`
    Title   string `json:"title" binding:"omitempty,max=100"`
    Status  int    `json:"status" binding:"omitempty,oneof=1 2"`
}
```

Handler mapping rule:

```go
query.AppID = req.AppID
query.AgentID = req.AgentID
input.AppID = req.AppID
input.AgentID = req.AgentID
```

Do not silently invent an app when both IDs are absent; service must reject create with `AI应用ID不能为空`.

- [ ] **Step 4: Move repository SQL from ai_agents to ai_apps**

`repository.go` must use `c.app_id` and `ai_apps`, never `c.agent_id` or `ai_agents`:

```go
if query.AppID != nil {
    db = db.Where("c.app_id = ?", *query.AppID)
} else if query.AgentID != nil {
    db = db.Where("c.app_id = ?", *query.AgentID)
}

err := db.Select(`c.id, c.user_id, c.app_id, c.title, c.last_message_at, c.status, c.is_del, c.created_at, c.updated_at, a.name as app_name`).
    Joins("LEFT JOIN ai_apps a ON a.id = c.app_id AND a.is_del = ?", enum.CommonNo).
    Order("c.last_message_at DESC").
    Order("c.id DESC").
    Limit(query.PageSize).
    Offset((query.CurrentPage - 1) * query.PageSize).
    Scan(&flats).Error
```

Replace `AgentName` / `ActiveAgentExists` with app equivalents:

```go
func (r *GormRepository) AppName(ctx context.Context, id int64) (string, error) {
    var name string
    err := r.db.WithContext(ctx).Table("ai_apps").Where("id = ?", id).Where("is_del = ?", enum.CommonNo).Pluck("name", &name).Error
    return name, err
}

func (r *GormRepository) ActiveAppExists(ctx context.Context, id int64) (bool, error) {
    var count int64
    err := r.db.WithContext(ctx).Table("ai_apps").Where("id = ?", id).Where("is_del = ?", enum.CommonNo).Where("status = ?", enum.CommonYes).Count(&count).Error
    return count > 0, err
}
```

- [ ] **Step 5: Normalize app_id in service**

Add one small helper; do not spread alias logic across methods:

```go
func effectiveAppID(appID int64, legacyAgentID int64) int64 {
    if appID > 0 {
        return appID
    }
    return legacyAgentID
}
```

`normalizeCreate` must validate active `ai_apps` and create `Conversation{AppID: appID}`:

```go
appID := effectiveAppID(input.AppID, input.AgentID)
if appID <= 0 {
    return Conversation{}, apperror.BadRequest("AI应用ID不能为空")
}
ok, err := repo.ActiveAppExists(ctx, appID)
if err != nil {
    return Conversation{}, apperror.Wrap(apperror.CodeInternal, 500, "校验AI应用失败", err)
}
if !ok {
    return Conversation{}, apperror.BadRequest("关联的AI应用不存在或已禁用")
}
```

Response mapping keeps aliases from the same value:

```go
AppID: c.AppID, AppName: row.AppName,
AgentID: c.AppID, AgentName: row.AppName,
```

- [ ] **Step 6: Update route/server tests and contract**

`admin_back_go/internal/server/router_test.go` should send `app_id` in new AI conversation examples:

```go
{http.MethodPost, "/api/admin/v1/ai-conversations", `{"app_id":1,"title":"会话"}`},
{http.MethodPut, "/api/admin/v1/ai-conversations/1", `{"app_id":1,"title":"会话"}`},
```

`docs/contracts/admin-api-v1.md` AI Conversations section must say:

```text
status: partially rebuilt for Dify sidecar app schema; Vue adaptation pending.
list supports app_id; agent_id is legacy alias for one migration pass.
table column is ai_conversations.app_id, joined to ai_apps; ai_agents is not a valid runtime dependency after rebuild migration.
```

- [ ] **Step 7: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
rg -n "ai_agents|c\.agent_id|column:agent_id|ActiveAgentExists|AgentName\(" internal/module/aiconversation internal/server/router_test.go -S
```

Expected:

```text
go test PASS.
Residue scan has no ai_agents, c.agent_id, column:agent_id, ActiveAgentExists, or AgentName( in aiconversation active runtime code.
The string agent_id may remain only as JSON/form legacy alias fields and explicit comments/tests.
```

- [ ] **Step 8: Commit task 10**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiconversation internal/server/router_test.go
git -C E:\admin_go\admin_back_go commit -m "fix: align ai conversations with app schema"
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: record ai conversation app schema contract"
```

---

## Task 11: Vue typed API and page adaptation

**Files:**
- Create: `admin_front_ts/src/api/ai/engineConnections.ts`
- Create: `admin_front_ts/src/api/ai/apps.ts`
- Create: `admin_front_ts/src/api/ai/knowledgeMaps.ts`
- Create: `admin_front_ts/src/api/ai/toolMaps.ts`
- Modify: `admin_front_ts/src/api/ai/chat.ts`
- Modify: `admin_front_ts/src/api/ai/conversations.ts`
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Create: `admin_front_ts/src/views/Main/ai/providers/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/apps/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/composables/useAgents.ts` or replace with `useApps.ts`
- Modify: `admin_front_ts/src/views/Main/ai/runs/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/knowledge/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/tools/index.vue`
- Create: `admin_front_ts/tests/shared/ai/ai-engine-connection-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-app-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-knowledge-map-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-tool-map-api.test.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Add typed clients**

Each new API file must follow the existing `@/lib/http` pattern:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, Id, PaginatedResponse, RequestPayload } from '@/types/common'

export type JsonObject = Record<string, unknown>

function positiveID(value: Id | number, label: string): number {
  const id = typeof value === 'number' ? value : Number(value)
  if (!Number.isInteger(id) || id <= 0) throw new Error(`${label} must be a positive integer`)
  return id
}
```

Create these clients with typed DTOs and no `legacyRequest`, no `any`, no `Record<string, any>`:

```text
engineConnections.ts -> /api/admin/v1/ai-engine-connections
apps.ts              -> /api/admin/v1/ai-apps and /api/admin/v1/ai-app-bindings
visible options      -> AiAppApi.options() backed by GET /api/admin/v1/ai-apps/options
knowledgeMaps.ts     -> /api/admin/v1/ai-knowledge-maps and ai-knowledge-documents
toolMaps.ts          -> /api/admin/v1/ai-tool-maps
```

Minimum exported shapes that tests must lock:

```ts
export interface AiEngineConnectionItem {
  id: number
  name: string
  engine_type: 'dify' | 'eino' | 'direct' | 'ragflow'
  base_url: string
  api_key_masked?: string | null
  health_status: 'unknown' | 'healthy' | 'unhealthy'
  status: number
  created_at: string
  updated_at: string
}

export interface AiAppOption {
  id: number
  name: string
  avatar?: string | null
  description?: string | null
  engine_connection_id: number
  engine_type: string
}

export interface AiAppMutationParams {
  id?: number
  name: string
  engine_connection_id: number
  engine_app_id: string
  app_type: 'chat' | 'workflow' | 'agent'
  engine_app_api_key?: string
  runtime_config?: JsonObject | null
  status?: number
}
```

Tests should assert exact URLs, methods, params normalization, and that source files do not contain `legacyRequest`, `api_key_enc`, `engine_app_api_key_enc`, or browser-side `Authorization` construction.

- [ ] **Step 1a: Preserve dynamic-route truth**

Do not create or edit `src/router/routes/modules/ai.ts`; this repository does not have route module files. Dynamic AI routes come from DB `permissions.component` plus `src/router/view-registry.ts`, which resolves components with `import.meta.glob('../views/Main/**/*.vue')`.

Required implementation effects:

```text
DB menu components must point to existing view keys:
  ai/providers
  ai/apps
  ai/chat
  ai/knowledge
  ai/runs
  ai/tools

Create view folders when the migration introduces a new component key:
  admin_front_ts/src/views/Main/ai/providers/index.vue
  admin_front_ts/src/views/Main/ai/apps/index.vue

Keep existing paths for pages that remain:
  admin_front_ts/src/views/Main/ai/chat/index.vue
  admin_front_ts/src/views/Main/ai/knowledge/index.vue
  admin_front_ts/src/views/Main/ai/runs/index.vue
  admin_front_ts/src/views/Main/ai/tools/index.vue
```

Also update menu labels:

```text
admin_front_ts/src/i18n/locales/zh-CN.ts: add ai_providers='供应商配置', ai_apps='智能体配置'; keep ai_chat/ai_knowledge/ai_runs/ai_tools.
admin_front_ts/src/i18n/locales/en-US.ts: add ai_providers='Providers', ai_apps='AI Apps'; keep existing active labels.
```

- [ ] **Step 1b: Conversation client app_id migration**

`admin_front_ts/src/api/ai/conversations.ts` must send and receive `app_id` as the primary field. Keep `agent_id` only as explicit legacy alias so the existing chat UI can be renamed safely.

Required type direction:

```ts
export interface AiConversationListParams extends RequestPayload {
  current_page?: number
  page_size?: number
  status?: number | ''
  app_id?: number | ''
  agent_id?: number | '' // legacy alias only
  title?: string
}

export interface AiConversationItem {
  id: number
  user_id: number
  app_id: number
  app_name: string
  agent_id?: number
  agent_name?: string
  title: string
  last_message_at: string
  status: number
  status_name: string
  created_at: string
  updated_at: string
}
```

Normalization rule:

```text
If app_id is a number, send app_id.
Else if legacy agent_id is a number, send app_id=<agent_id> only if the caller has not been migrated yet.
New chat code must pass app_id, not agent_id.
```

The API test must assert `AiConversationApi.list({ app_id: 7 })` sends `app_id=7` and does not send `agent_id`.

- [ ] **Step 2: Chat page app selector**

Chat page loads active app options from `AiAppApi.options()`, backed by `GET /api/admin/v1/ai-apps/options`. New runtime calls send `app_id`, not `agent_id`:

```ts
export interface StreamParams {
  content: string
  conversation_id?: number
  app_id?: number
  max_history?: number
  attachments?: Attachment[]
  temperature?: number
  max_tokens?: number
}

interface StreamStartResponse {
  conversation_id: number
  run_id: number
  request_id: string
  user_message_id: number
  app_id: number
  agent_id?: number
  is_new: boolean
}
```

If no active app exists, show this explicit empty state and disable send:

```text
请先配置 AI 应用和 Dify 连接
```

The current UI can keep component names like `AgentList` for one pass if renaming would explode the diff, but displayed copy and data types must say AI 应用 / 智能体配置, and all new payloads must use `app_id`.

- [ ] **Step 3: Runs page event drawer**

Runs page must switch filters and labels to app/engine while preserving legacy aliases only for display compatibility:

```text
page-init reads dict.appArr and dict.engineArr.
list query sends app_id and engine_connection_id.
list rows render app_name and engine_name first; agent_name is alias only.
statsByAgent route may remain route-compatible, but chart labels must treat it as app statistics.
```

Runs detail drawer reads persisted `events` from `GET /api/admin/v1/ai-runs/:id`, not browser-only WebSocket state. The frontend type must include:

```ts
export interface AiRunEventItem {
  id: number
  seq: number
  event_id: string
  event_type: string
  delta_text: string
  payload_json?: Record<string, unknown> | null
  created_at: string
}
```

- [ ] **Step 3a: Rename chat mental model from agent to app without breaking route**

The current chat page has `composables/useAgents.ts` and API payloads using `agent_id`. Do not let that naming drive the new backend. Implement this compatibility layer:

```text
Preferred request field: app_id.
Accepted legacy request field during this migration: agent_id, mapped server-side to app_id.
Frontend selector label: 智能体配置 / AI 应用, backed by ai_apps/options.
No Vue code may call Dify or carry Dify API keys.
```

If renaming the composable is low-risk, create `useApps.ts` and leave `useAgents.ts` as a thin re-export for one pass. If the page is already too tangled, keep the filename but change the exported types to `AiAppOption` and remove `agent_id` from new calls.

- [ ] **Step 3b: Provider/App pages and existing knowledge/tool pages**

Create minimal, maintainable route views for the two new product entries and adapt existing knowledge/tool pages without UI reinvention:

```text
providers/index.vue: table + edit dialog + server-side test action. Never render plaintext API keys; only show masked hint.
apps/index.vue: table + Dify app mapping dialog + optional binding list. engine_app_api_key is write-only.
knowledge/index.vue: use knowledgeMaps.ts for dataset/document mapping and explicit sync/refresh actions; do not keep calling old ai-knowledge-bases as the main path.
tools/index.vue: use toolMaps.ts; show risk_level and permission_code; no direct internal API execution button in this slice.
```

Component map required before implementation in the PR/task note:

```text
Provider view = data orchestration only; ProviderDialog handles create/edit/test form.
App view = data orchestration only; AppDialog handles app mapping; BindingPanel handles bindings.
Knowledge view = map table + document panel; sync is explicit action.
Tool view = map table + dialog; risk display is computed from typed enum.
```

Keep Vue SFC rules: `<script setup lang="ts">`, minimal source state, derived labels via `computed`, props down/events up for child components, no `v-html` for engine payloads.

- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-engine-connection-api.test.ts tests/shared/ai/ai-app-api.test.ts tests/shared/ai/ai-knowledge-map-api.test.ts tests/shared/ai/ai-tool-map-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npm run build:check
rg -n "legacyRequest|api_key_enc|engine_app_api_key_enc|Authorization: Bearer|EventSource|text/event-stream|agent_id" src/api/ai src/views/Main/ai tests/shared/ai tests/shared/http -S
```

Expected:

```text
Vitest targeted AI contract tests PASS.
build:check PASS.
Residue scan has no legacyRequest, secret ciphertext fields, browser-side Bearer construction, EventSource, or text/event-stream.
agent_id appears only in explicit compatibility tests/comments or legacy alias handling; new chat payload code uses app_id.
```

- [ ] **Step 5: Commit task 11**

```powershell
git -C E:\admin_go\admin_front_ts add src/api/ai src/views/Main/ai src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/ai tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
git -C E:\admin_go\admin_front_ts commit -m "feat: adapt vue ai pages to engine-backed contracts"
```

---

## Task 12: Docs, smoke matrix, and final verification

**Files:**
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`
- Modify: `admin_back_go/scripts/basic-admin-smoke.ps1`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`

- [x] **Step 0: Remove deterministic provider from production aichat**

The current final-residue scan still finds:

```text
admin_back_go/internal/module/aichat/service.go:656:type deterministicProvider struct{}
admin_back_go/internal/module/aichat/service.go:658:func (deterministicProvider) Generate(...)
admin_back_go/internal/module/aichat/service.go:662:ModelSnapshot: "go-deterministic-provider"
```

That is bad taste. Bootstrap no longer injects it, but a production source file still contains a fake success provider. Clean means it is gone from production code, not merely unused.

Preferred edit:

```text
admin_back_go/internal/module/aichat/dto.go:
  remove GenerateInput
  remove GenerateResult
  remove Provider interface

admin_back_go/internal/module/aichat/service.go:
  remove Dependencies.Provider
  remove Service.provider
  remove executeWithLegacyProvider
  remove deterministicProvider
  when engineForApp fails, always mark failed and return the explicit appErr

admin_back_go/internal/module/aichat/service_test.go:
  remove fakeProvider
  replace TestExecuteRunMarksSuccessAndFailure with engine-backed success/failure tests:
    success uses platformai.NewFakeEngine("ok")
    failure uses a fakeEngineFactory returning an error or a fake engine that returns a StreamChat error
```

The implementation shape in `ExecuteRun` must stay simple:

```go
engine, appErr := s.engineForApp(ctx, record.App)
if appErr != nil {
    msg := appErr.Message
    _ = repo.MarkFailed(ctx, input.RunID, msg)
    sink := newPersistentSink(repo, s.publisher, record.Run.UserID, input.RunID, s.now)
    if event, buildErr := BuildFailedEvent(input.RunID, msg); buildErr == nil {
        _ = sink.emitEnvelope(ctx, event, msg)
    }
    return nil, appErr
}
```

After the edit:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\aichat\dto.go .\internal\module\aichat\service.go .\internal\module\aichat\service_test.go
go test ./internal/module/aichat -count=1
rg -n "deterministicProvider|go-deterministic-provider|type Provider|GenerateInput|GenerateResult|executeWithLegacyProvider" internal/module/aichat -S
```

Expected:

```text
go test PASS
residue scan has no output outside historical docs
```

- [ ] **Step 1: Rewrite AI route gates in basic smoke**

`admin_back_go/scripts/basic-admin-smoke.ps1` currently still treats `/ai/models` as retained. That is wrong after the Dify sidecar rebuild.

Replace the AI users/init assertions with this contract:

```powershell
$retiredAIRoutes = @('/ai/goods', '/ai/cine', '/ai/models', '/ai/agents', '/ai/prompts')
foreach ($route in $retiredAIRoutes) {
  if (Test-RoutePath $init.data.router $route) {
    throw "users init still returns retired AI route $route; run AI core rebuild migration and clear operator-side caches"
  }
}

$requiredAIRoutes = @('/ai/providers', '/ai/apps', '/ai/chat', '/ai/knowledge', '/ai/runs', '/ai/tools')
foreach ($route in $requiredAIRoutes) {
  if (-not (Test-RoutePath $init.data.router $route)) {
    throw "users init missing AI sidecar product route $route"
  }
}
```

Update the summary keys to match the new surface:

```powershell
ai_providers_route_present = Test-RoutePath $init.data.router '/ai/providers'
ai_apps_route_present = Test-RoutePath $init.data.router '/ai/apps'
ai_chat_route_present = Test-RoutePath $init.data.router '/ai/chat'
ai_knowledge_route_present = Test-RoutePath $init.data.router '/ai/knowledge'
ai_runs_route_present = Test-RoutePath $init.data.router '/ai/runs'
ai_tools_route_present = Test-RoutePath $init.data.router '/ai/tools'
ai_models_route_present = Test-RoutePath $init.data.router '/ai/models' # must be false
ai_agents_route_present = Test-RoutePath $init.data.router '/ai/agents' # must be false
ai_prompts_route_present = Test-RoutePath $init.data.router '/ai/prompts' # must be false
```

- [ ] **Step 2: Rewrite AI probes in full smoke**

`admin_back_go/scripts/full-admin-smoke.ps1` must stop calling old active routes:

```text
REMOVE probes:
  GET /api/admin/v1/ai-models/page-init
  GET /api/admin/v1/ai-models
  GET /api/admin/v1/ai-tools/page-init
  GET /api/admin/v1/ai-tools
  GET /api/admin/v1/ai-tools/agent-options
  GET /api/admin/v1/ai-prompts
  GET /api/admin/v1/ai-prompts/:id
  GET /api/admin/v1/ai-agents/page-init
  GET /api/admin/v1/ai-agents
  GET /api/admin/v1/ai-knowledge-bases/page-init
  GET /api/admin/v1/ai-knowledge-bases
```

`Assert-UsersInitAIRoutes` must assert:

```text
Retired absent:
  /ai/goods
  /ai/cine
  /ai/models
  /ai/agents
  /ai/prompts

Required present:
  /ai/providers
  /ai/apps
  /ai/chat
  /ai/knowledge
  /ai/runs
  /ai/tools
```

Add replacement probes:

```powershell
$aiEngineInit = Invoke-RestMethod "$baseURL/api/admin/v1/ai-engine-connections/page-init" -Headers $authHeaders -TimeoutSec 10
$aiEngineList = Invoke-RestMethod "$baseURL/api/admin/v1/ai-engine-connections?current_page=1&page_size=20" -Headers $authHeaders -TimeoutSec 10
$aiAppInit = Invoke-RestMethod "$baseURL/api/admin/v1/ai-apps/page-init" -Headers $authHeaders -TimeoutSec 10
$aiAppList = Invoke-RestMethod "$baseURL/api/admin/v1/ai-apps?current_page=1&page_size=20" -Headers $authHeaders -TimeoutSec 10
$aiAppOptions = Invoke-RestMethod "$baseURL/api/admin/v1/ai-apps/options" -Headers $authHeaders -TimeoutSec 10
$aiKnowledgeMapInit = Invoke-RestMethod "$baseURL/api/admin/v1/ai-knowledge-maps/page-init" -Headers $authHeaders -TimeoutSec 10
$aiKnowledgeMapList = Invoke-RestMethod "$baseURL/api/admin/v1/ai-knowledge-maps?current_page=1&page_size=20" -Headers $authHeaders -TimeoutSec 10
$aiToolMapInit = Invoke-RestMethod "$baseURL/api/admin/v1/ai-tool-maps/page-init" -Headers $authHeaders -TimeoutSec 10
$aiToolMapList = Invoke-RestMethod "$baseURL/api/admin/v1/ai-tool-maps?current_page=1&page_size=20" -Headers $authHeaders -TimeoutSec 10
```

Shape requirements:

```text
ai-engine-connections page-init has dict.engine_type_arr, dict.common_status_arr, dict.health_status_arr.
ai-engine-connections list has page/list and never returns api_key/api_key_enc/Authorization/Bearer.
ai-apps page-init has dict.app_type_arr, dict.response_mode_arr, dict.binding_type_arr, dict.engine_connection_options.
ai-apps list/options never returns engine_app_api_key/engine_app_api_key_enc.
ai-knowledge-maps page-init has visibility/source/indexing/common status dictionaries and engine_connection_options.
ai-tool-maps page-init has tool_type_arr, risk_level_arr, common_status_arr, engine_connection_options.
all replacement list responses have page/list shape and pass Assert-NoAISecretFields.
```

Keep existing Dify-disabled and optional Dify-enabled chat probes:

```text
POST /api/admin/v1/ai-chat/runs without DIFY_SMOKE_APP_ID must fail with explicit AI app/engine config error, not deterministic success.
POST /api/admin/v1/ai-chat/runs with -EnableAiEngineProbe and DIFY_SMOKE_APP_ID must return run_id and not leak secrets.
```

Update full-smoke summary keys:

```text
ai_engine_init_code / ai_engine_list_code / ai_engine_total / ai_engine_secret_leak=false
ai_app_init_code / ai_app_list_code / ai_app_options_code / ai_app_total
ai_knowledge_map_init_code / ai_knowledge_map_list_code / ai_knowledge_map_total
ai_tool_map_init_code / ai_tool_map_list_code / ai_tool_map_total
ai_providers_route_present / ai_apps_route_present / ai_chat_route_present / ai_knowledge_route_present / ai_runs_route_present / ai_tools_route_present
ai_models_route_present=false / ai_agents_route_present=false / ai_prompts_route_present=false
```

- [ ] **Step 3: Update architecture docs**

Document:

```text
Dify is sidecar AI engine.
admin_go owns RBAC/audit/local run mirror.
internal/platform/ai is the only engine boundary.
Dify API keys are server-only encrypted secrets.
Old aimodel/aitool/aiprompt/aiagent/aiknowledge routes are retired from active server/bootstrap.
```

- [ ] **Step 4: Update contract/status/smoke docs honestly**

`docs/contracts/admin-api-v1.md`:

```text
Auth Requirement Matrix must reference the new resources:
  ai-engine-connections / ai-apps / ai-knowledge-maps / ai-tool-maps
  ai-conversations / ai-messages / ai-chat / ai-runs

The old AI Core P1 Config and AI Agent / Knowledge sections must be marked retired/superseded and must not claim active Go routes after 20260508_ai_core_rebuild.sql.
Keep old endpoint lists only as historical migration notes, not active contract.
```

`docs/migration/current-status.md`:

```text
Replace the old three-row AI story with one current truth:
  AI core Dify sidecar rebuild = partially rebuilt, not fully implemented until smoke/final Dify probe evidence.
  backend active runtime uses ai_engine_connections/ai_apps/ai_knowledge_maps/ai_tool_maps/aiconversation/aimessage/aichat/airun.
  old aimodel/aitool/aiprompt/aiagent/aiknowledge are unmounted/retired and may be deleted after residue scan.
  frontend six entries have been adapted in the dirty tree, pending final build/smoke evidence.
```

`docs/testing/smoke-matrix.md`:

```text
Replace AI config P1 REST and AI agent/knowledge management rows with:
  AI sidecar menu gate
  AI provider/app/map config read
  AI chat/runtime/runs disabled-baseline + optional Dify probe

Do not say /ai/models, /ai/prompts, /api/admin/v1/ai-models, /api/admin/v1/ai-agents, or /api/admin/v1/ai-knowledge-bases are expected present.
```

- [ ] **Step 5: PowerShell parse smoke scripts**

Run:

```powershell
cd E:\admin_go\admin_back_go
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\basic-admin-smoke.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { $errors | Format-List; exit 1 } else { 'basic-ps-parse-ok' }
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\full-admin-smoke.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { $errors | Format-List; exit 1 } else { 'full-ps-parse-ok' }
```

Expected:

```text
basic-ps-parse-ok
full-ps-parse-ok
```

- [ ] **Step 6: Run backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai ./internal/platform/ai/dify ./internal/module/aiengine ./internal/module/aiapp ./internal/module/aiknowledgemap ./internal/module/aitoolmap ./internal/module/aichat ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/server ./internal/bootstrap -count=1

powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: PASS.

- [ ] **Step 7: Run frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-engine-connection-api.test.ts tests/shared/ai/ai-app-api.test.ts tests/shared/ai/ai-knowledge-map-api.test.ts tests/shared/ai/ai-tool-map-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npm run build:check
rg -n "legacyRequest|api_key_enc|engine_app_api_key_enc|Authorization: Bearer|EventSource|text/event-stream" src/api/ai src/views/Main/ai tests/shared/ai tests/shared/http -S
```

Expected:

```text
Vitest PASS.
build:check PASS.
residue scan has no output.
```

- [ ] **Step 8: Run smoke**

Dify-disabled baseline:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Dify-enabled optional probe when test sidecar exists:

```powershell
cd E:\admin_go\admin_back_go
$env:DIFY_SMOKE_APP_ID='configured-admin-go-smoke-app-id'
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456 -EnableAiEngineProbe
```

Expected:

```text
Disabled baseline proves no fake deterministic success.
Enabled probe proves engine ids/events are stored.
No response contains api_key/api_key_enc/Authorization Bearer values.
```

- [ ] **Step 9: Final residue scan**

```powershell
cd E:\admin_go
rg -n "internal/module/(aimodel|aitool\b|aiagent|aiknowledge\b|aiprompt)|\baimodel\.|\baitool\.|\baiagent\.|\baiknowledge\.|\baiprompt\." admin_back_go/internal/server admin_back_go/internal/bootstrap -S
rg -n "ai-models|ai-tools/agent-options|ai-prompts|ai-agents|ai-knowledge-bases|/ai/models|/ai/agents|/ai/prompts" admin_back_go/internal/server admin_back_go/internal/bootstrap admin_back_go/scripts admin_back_go/docs docs/contracts docs/migration docs/testing -S
rg -n "deterministicProvider|go-deterministic-provider|legacyRequest\(.*ai|DIFY_API_KEY|api_key_enc" admin_back_go admin_front_ts docs/contracts docs/migration docs/testing -S
```

Expected:

```text
No old module imports in server/bootstrap.
Old active route strings appear only in negative retired-route tests, backup/rollback SQL, or historical superpowers docs outside active contract/status/smoke docs.
deterministicProvider only appears in tests or historical/spec discussion, not bootstrap production constructors.
legacyRequest is absent from active AI API clients.
DIFY_API_KEY does not appear in frontend.
api_key_enc appears only in backend model/migration/masking tests/docs, never in response DTO or smoke output.
```

- [ ] **Step 10: Commit final docs**

```powershell
git -C E:\admin_go\admin_back_go add docs/architecture.md
git -C E:\admin_go\admin_back_go commit -m "docs: record ai dify sidecar backend architecture"
git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/contracts/admin-realtime-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md
git -C E:\admin_go commit -m "docs: record ai dify sidecar runtime truth"
```

---

## Execution order

```text
Historical full-plan order:
  Task 1 must run before all code tasks.
  Task 2 must run before Task 3 and Task 8.
  Task 3 can run in parallel with Task 4/5 only if write sets stay separate.
  Task 4 must run before Task 5.
  Task 5 must run before Task 8.
  Task 6 and Task 7 can run after Task 4.
  Task 8 must run before Task 9.
  Task 10 must run before Vue because `aiconversation` needed `app_id` schema cleanup.
  Task 11 starts only after Task 10 backend conversation cleanup passes.
  Task 12 is last.

Current continuation order on 2026-05-09:
  Start at final verification or the non-AI full-smoke maintenance note, not at Task 1.
  Do not re-run or rewrite Task 1-12 unless a verification gate exposes drift.
  Do not touch unrelated payment patch files unless the user explicitly asks to make full-admin-smoke green end-to-end.
```

## Stop conditions

```text
Stop if backup SQL cannot run on the target DB.
Stop if Dify app API key would need to be exposed to Vue.
Stop if module code imports Dify/OpenAI/Eino client directly.
Stop if full smoke sees deterministic provider output in a production-like path.
Stop if OperationLog captures plaintext api_key or Authorization header.
```
