# AI Core Migration Prune Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the AI core migration by deleting the AI e-commerce script and AI cine factory modules from schema, permissions, frontend entrypoints, and active docs while preserving AI core history and runtime facts.

**Architecture:** This is Phase 0, not the Go AI runtime rewrite. Use one destructive DB migration for module-owned tables and menu grants; use soft-delete for core AI rows that are still referenced by conversations/runs/messages; remove dead Vue entrypoints and upload folder constants; leave cache clearing to the operator.

**Tech Stack:** MySQL 8.x, Go/Gin modular monolith under `admin_back_go`, Vue 3 + TypeScript under `admin_front_ts`, existing repo smoke scripts, existing `permissions` / `role_permissions` / `users_quick_entry` menu model.

---

## Master rule

Do not migrate core AI APIs in this plan. Delete only the two retired product modules: AI 电商口播 (`/ai/goods`) and AI 短剧工厂 (`/ai/cine`). Keep AI models/agents/knowledge/chat/runs/prompts/tools alive.

## File map

### Create

- `admin_back_go/database/migrations/20260508_remove_ai_goods_cine_modules.sql`

### Modify

- `admin_back_go/internal/enum/upload.go`
- `admin_back_go/scripts/basic-admin-smoke.ps1`
- `docs/contracts/admin-api-v1.md`
- `docs/migration/current-status.md`
- `docs/testing/smoke-matrix.md`
- `admin_back_go/docs/architecture.md`
- `admin_front_ts/src/i18n/locales/zh-CN.ts`
- `admin_front_ts/src/i18n/locales/en-US.ts`
- `admin_front_ts/src/views/Main/ai/agents/composables/helpers.ts`
- `admin_front_ts/tests/shared/ai/agent-helpers.test.ts`

### Delete

- `admin_front_ts/src/api/ai/goods.ts`
- `admin_front_ts/src/api/ai/cine.ts`
- `admin_front_ts/src/views/Main/ai/goods/`
- `admin_front_ts/src/views/Main/ai/cine/`
- `admin_front_ts/tests/shared/ai/goods-helpers.test.ts`
- `admin_front_ts/tests/shared/dialog/goods-dialog.test.ts`

---

## Task 1: Lock the current DB and code evidence

**Files:** no source changes

- [ ] **Step 1: Confirm clean worktrees**

Run:

```powershell
git -C E:\admin_go status --short
git -C E:\admin_go\admin_back_go status --short
git -C E:\admin_go\admin_front_ts status --short
```

Expected: no output, or only files intentionally created by this plan.

- [ ] **Step 2: Capture table and permission facts**

Run against the `admin` database:

```sql
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('goods', 'cine_projects', 'cine_assets')
ORDER BY table_name;

SELECT p.id, p.parent_id, p.name, p.path, p.component, p.i18n_key, COUNT(rp.role_id) AS role_grants
FROM permissions p
LEFT JOIN role_permissions rp ON rp.permission_id = p.id AND rp.is_del = 2
WHERE p.platform = 'admin'
  AND p.is_del = 2
  AND (p.path IN ('/ai/goods', '/ai/cine') OR p.component IN ('ai/goods', 'ai/cine'))
GROUP BY p.id, p.parent_id, p.name, p.path, p.component, p.i18n_key
ORDER BY p.id;

SELECT a.id AS agent_id, a.name, a.scene, COUNT(DISTINCT c.id) AS conversations, COUNT(DISTINCT r.id) AS runs
FROM ai_agents a
LEFT JOIN ai_conversations c ON c.agent_id = a.id
LEFT JOIN ai_runs r ON r.agent_id = a.id
WHERE a.scene IN ('goods_script', 'cine_project', 'cine_keyframe')
GROUP BY a.id, a.name, a.scene
ORDER BY a.id;
```

Expected current facts:

```text
goods exists, cine_projects exists, cine_assets exists
/ai/goods has role grants
/ai/cine has role grants
goods/cine scene agents have conversation/run references, so they must be soft-deleted, not hard-deleted
```

- [ ] **Step 3: Keep an out-of-schema backup artifact**

Run before applying the destructive migration if `mysqldump` is available:

```powershell
cd E:\admin_go\admin_back_go
New-Item -ItemType Directory -Force -Path .\runtime\migration_backups\20260508_ai_prune | Out-Null
mysqldump --no-data admin goods cine_projects cine_assets > .\runtime\migration_backups\20260508_ai_prune\removed_tables_schema.sql
mysqldump admin goods cine_projects cine_assets > .\runtime\migration_backups\20260508_ai_prune\removed_tables_data.sql
```

Expected: two files under ignored `runtime/`; no backup tables are created inside the live DB schema.

---

## Task 2: Add the destructive DB migration

**Files:**

- Create: `admin_back_go/database/migrations/20260508_remove_ai_goods_cine_modules.sql`

- [ ] **Step 1: Create migration file**

Create `admin_back_go/database/migrations/20260508_remove_ai_goods_cine_modules.sql` with exactly this SQL:

```sql
-- Remove retired AI product modules before Go AI core migration.
--
-- Product decision: AI e-commerce script and AI cine factory are out of scope.
-- This migration removes their menu grants and module-owned tables. Core AI
-- history stays: conversations, messages, runs, run steps, and referenced agents
-- are preserved for audit by soft-deleting scene-specific selectors only.
-- Cache/ButtonGrant invalidation is intentionally not performed here.

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_permissions`;
CREATE TEMPORARY TABLE `tmp_ai_prune_permissions` (
    `id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_parent_permissions`;
CREATE TEMPORARY TABLE `tmp_ai_prune_parent_permissions` (
    `id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO `tmp_ai_prune_permissions` (`id`)
SELECT `id`
FROM `permissions`
WHERE `platform` = 'admin'
  AND (
      `path` IN ('/ai/goods', '/ai/cine')
      OR `path` LIKE '/ai/goods/%'
      OR `path` LIKE '/ai/cine/%'
      OR `component` IN ('ai/goods', 'ai/cine')
      OR `component` LIKE 'ai/goods/%'
      OR `component` LIKE 'ai/cine/%'
      OR `i18n_key` IN ('menu.ai_goods', 'menu.ai_cine')
      OR `code` LIKE 'ai_goods\_%'
      OR `code` LIKE 'ai_cine\_%'
  );

INSERT IGNORE INTO `tmp_ai_prune_parent_permissions` (`id`)
SELECT `id`
FROM `tmp_ai_prune_permissions`;

INSERT IGNORE INTO `tmp_ai_prune_permissions` (`id`)
SELECT child.`id`
FROM `permissions` AS child
JOIN `tmp_ai_prune_parent_permissions` AS parent ON parent.`id` = child.`parent_id`
WHERE child.`platform` = 'admin';

UPDATE `users_quick_entry` AS uq
JOIN `tmp_ai_prune_permissions` AS doomed ON doomed.`id` = uq.`permission_id`
SET uq.`is_del` = 1,
    uq.`updated_at` = NOW()
WHERE uq.`is_del` = 2;

DELETE rp
FROM `role_permissions` AS rp
JOIN `tmp_ai_prune_permissions` AS doomed ON doomed.`id` = rp.`permission_id`;

DELETE p
FROM `permissions` AS p
JOIN `tmp_ai_prune_permissions` AS doomed ON doomed.`id` = p.`id`;

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_parent_permissions`;
DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_permissions`;

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_scene_agents`;
CREATE TEMPORARY TABLE `tmp_ai_prune_scene_agents` (
    `id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO `tmp_ai_prune_scene_agents` (`id`)
SELECT `id`
FROM `ai_agents`
WHERE `scene` IN ('goods_script', 'cine_project', 'cine_keyframe');

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_tools`;
CREATE TEMPORARY TABLE `tmp_ai_prune_tools` (
    `id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO `tmp_ai_prune_tools` (`id`)
SELECT `id`
FROM `ai_tools`
WHERE `code` = 'cine_generate_keyframe';

UPDATE `ai_agent_scenes`
SET `status` = 2,
    `is_del` = 1,
    `updated_at` = NOW()
WHERE `is_del` = 2
  AND `scene_code` IN ('goods_script', 'cine_project', 'cine_keyframe');

UPDATE `ai_assistant_tools` AS aat
LEFT JOIN `tmp_ai_prune_scene_agents` AS a ON a.`id` = aat.`assistant_id`
LEFT JOIN `tmp_ai_prune_tools` AS t ON t.`id` = aat.`tool_id`
SET aat.`status` = 2,
    aat.`is_del` = 1,
    aat.`updated_at` = NOW()
WHERE aat.`is_del` = 2
  AND (a.`id` IS NOT NULL OR t.`id` IS NOT NULL);

UPDATE `ai_agents` AS a
JOIN `tmp_ai_prune_scene_agents` AS doomed ON doomed.`id` = a.`id`
SET a.`status` = 2,
    a.`is_del` = 1,
    a.`updated_at` = NOW()
WHERE a.`is_del` = 2;

UPDATE `ai_tools` AS t
JOIN `tmp_ai_prune_tools` AS doomed ON doomed.`id` = t.`id`
SET t.`status` = 2,
    t.`is_del` = 1,
    t.`updated_at` = NOW()
WHERE t.`is_del` = 2;

DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_scene_agents`;
DROP TEMPORARY TABLE IF EXISTS `tmp_ai_prune_tools`;

DROP TABLE IF EXISTS `cine_assets`;
DROP TABLE IF EXISTS `cine_projects`;
DROP TABLE IF EXISTS `goods`;
```

- [ ] **Step 2: Review migration for MySQL temporary table self-join bug**

Run:

```powershell
Select-String -Path E:\admin_go\admin_back_go\database\migrations\20260508_remove_ai_goods_cine_modules.sql -Pattern 'tmp_ai_prune_permissions|tmp_ai_prune_parent_permissions'
```

Expected: parent snapshot table exists; subtree deletion does not self-join the same temporary table being mutated.

- [ ] **Step 3: Commit backend migration after review**

```powershell
git -C E:\admin_go\admin_back_go add database/migrations/20260508_remove_ai_goods_cine_modules.sql
git -C E:\admin_go\admin_back_go commit -m "feat: prune retired AI product schemas"
```

Expected: one backend commit, no frontend/root files included.

---

## Task 3: Apply and verify the DB migration

**Files:** no source changes

- [ ] **Step 1: Apply migration**

Use the repo's normal MySQL access method. If using the MySQL CLI directly, run:

```powershell
mysql --database=admin < E:\admin_go\admin_back_go\database\migrations\20260508_remove_ai_goods_cine_modules.sql
```

Expected: command exits 0.

- [ ] **Step 2: Verify removed tables are gone**

Run:

```sql
SELECT COUNT(*) AS table_left
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('goods', 'cine_projects', 'cine_assets');
```

Expected:

```text
table_left = 0
```

- [ ] **Step 3: Verify removed menu rows and grants are gone**

Run:

```sql
SELECT COUNT(*) AS permission_left
FROM permissions
WHERE platform = 'admin'
  AND is_del = 2
  AND (
    path IN ('/ai/goods', '/ai/cine')
    OR component IN ('ai/goods', 'ai/cine')
    OR i18n_key IN ('menu.ai_goods', 'menu.ai_cine')
  );

SELECT COUNT(*) AS active_quick_entry_left
FROM users_quick_entry uq
LEFT JOIN permissions p ON p.id = uq.permission_id
WHERE uq.is_del = 2
  AND (p.path IN ('/ai/goods', '/ai/cine') OR p.component IN ('ai/goods', 'ai/cine'));
```

Expected:

```text
permission_left = 0
active_quick_entry_left = 0
```

- [ ] **Step 4: Verify scene data is retired, not orphaned by hard delete**

Run:

```sql
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

Expected:

```text
active_scene_left = 0
active_scene_agent_left = 0
active_cine_tool_left = 0
```

- [ ] **Step 5: Verify AI core still exists**

Run:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'ai_models', 'ai_agents', 'ai_agent_scenes', 'ai_assistant_tools', 'ai_tools',
    'ai_conversations', 'ai_messages', 'ai_runs', 'ai_run_steps', 'ai_prompts',
    'ai_knowledge_bases', 'ai_knowledge_documents', 'ai_knowledge_chunks',
    'ai_agent_knowledge_bases'
  )
ORDER BY table_name;
```

Expected: all listed core AI tables are present.

---

## Task 4: Remove dead upload folders from Go active contract

**Files:**

- Modify: `admin_back_go/internal/enum/upload.go`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Remove retired folders from enum**

Edit `admin_back_go/internal/enum/upload.go` so `UploadFolders` keeps `ai_chat_images` but removes `goods_tts` and `cine_keyframes`:

```go
var UploadFolders = []string{
	"avatars",
	"images",
	"videos",
	"cover_images",
	"ai_chat_images",
	"releases",
	"tauri_updater",
	"exports",
	"reconcile_reports",
}
```

- [ ] **Step 2: Remove retired folders from docs**

In `docs/contracts/admin-api-v1.md`, update the upload token folder union so it no longer includes `goods_tts` or `cine_keyframes`, while still including `ai_chat_images` and `reconcile_reports`.

Search command:

```powershell
rg -n "goods_tts|cine_keyframes|ai_chat_images" E:\admin_go\docs E:\admin_go\admin_back_go\docs E:\admin_go\admin_back_go\internal\enum\upload.go
```

Expected after edit: only historical spec/plan files may still mention `goods_tts` or `cine_keyframes`; active contract/architecture/enum do not.

- [ ] **Step 3: Run backend focused verification**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/module/uploadtoken ./internal/module/uploadconfig
go vet -p=1 ./internal/enum ./internal/module/uploadtoken ./internal/module/uploadconfig
git diff --check
```

Expected: tests/vet/diff-check exit 0.

- [ ] **Step 4: Commit backend enum/docs changes**

```powershell
git -C E:\admin_go\admin_back_go add internal/enum/upload.go docs/architecture.md
git -C E:\admin_go add docs/contracts/admin-api-v1.md
git -C E:\admin_go\admin_back_go commit -m "refactor: remove retired AI upload folders"
git -C E:\admin_go commit -m "docs: remove retired AI upload folders"
```

Expected: backend and root docs commits are separate because they are different repos.

---

## Task 5: Delete frontend AI goods/cine modules

**Files:**

- Delete: `admin_front_ts/src/api/ai/goods.ts`
- Delete: `admin_front_ts/src/api/ai/cine.ts`
- Delete: `admin_front_ts/src/views/Main/ai/goods/`
- Delete: `admin_front_ts/src/views/Main/ai/cine/`
- Delete: `admin_front_ts/tests/shared/ai/goods-helpers.test.ts`
- Delete: `admin_front_ts/tests/shared/dialog/goods-dialog.test.ts`

- [ ] **Step 1: Remove files**

```powershell
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\src\api\ai\goods.ts -Force
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\src\api\ai\cine.ts -Force
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\src\views\Main\ai\goods -Recurse -Force
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\src\views\Main\ai\cine -Recurse -Force
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\tests\shared\ai\goods-helpers.test.ts -Force
Remove-Item -LiteralPath E:\admin_go\admin_front_ts\tests\shared\dialog\goods-dialog.test.ts -Force
```

Expected: removed files no longer exist.

- [ ] **Step 2: Verify no import points at deleted modules**

```powershell
rg -n "@/api/ai/(goods|cine)|views/Main/ai/(goods|cine)|ai/goods|ai/cine" E:\admin_go\admin_front_ts\src E:\admin_go\admin_front_ts\tests
```

Expected: no output except lines in i18n before Task 6 edits.

- [ ] **Step 3: Commit frontend deletion**

```powershell
git -C E:\admin_go\admin_front_ts add -A src/api/ai src/views/Main/ai tests/shared/ai tests/shared/dialog
git -C E:\admin_go\admin_front_ts commit -m "feat: remove retired AI product frontends"
```

Expected: one frontend commit.

---

## Task 6: Clean frontend labels and scene helpers

**Files:**

- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/composables/helpers.ts`
- Modify: `admin_front_ts/tests/shared/ai/agent-helpers.test.ts`

- [ ] **Step 1: Remove menu labels**

From both locale files remove:

```ts
ai_goods: '电商口播',
ai_cine: 'AI短剧工厂',
```

and in English:

```ts
ai_goods: 'E-commerce Script',
ai_cine: 'AI Cine Factory',
```

- [ ] **Step 2: Remove top-level locale blocks**

From both locale files remove the entire top-level `goods: { ... }` and `cine: { ... }` blocks.

Expected: `rg -n "^\s*(goods|cine): \{" src/i18n/locales` has no output.

- [ ] **Step 3: Remove goods-specific scene styling**

Change `admin_front_ts/src/views/Main/ai/agents/composables/helpers.ts`:

```ts
export function getAgentSceneTagType(_scene?: string | null): 'info' {
  return 'info'
}
```

- [ ] **Step 4: Update agent helper tests**

In `admin_front_ts/tests/shared/ai/agent-helpers.test.ts`, remove `goods_script` expectations and use a generic retained scene value for payload checks, for example `general_chat`:

```ts
expect(getAgentSceneTagType('general_chat')).toBe('info')
```

and payload fixtures should use:

```ts
scene: 'general_chat',
scene_codes: ['general_chat'],
```

- [ ] **Step 5: Verify frontend static residue**

```powershell
rg -n "ai_goods|ai_cine|/ai/goods|/ai/cine|goods_script|cine_project|cine_keyframe|goods\.|cine\." E:\admin_go\admin_front_ts\src E:\admin_go\admin_front_ts\tests
```

Expected: no output. If `goods` appears as a generic English word in unrelated code, inspect it manually and keep only unrelated occurrences.

- [ ] **Step 6: Run focused frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/ai/agent-helpers.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false
git diff --check
```

Expected: commands exit 0.

- [ ] **Step 7: Commit frontend cleanup**

```powershell
git -C E:\admin_go\admin_front_ts add -A src/i18n/locales src/views/Main/ai/agents/composables/helpers.ts tests/shared/ai/agent-helpers.test.ts
git -C E:\admin_go\admin_front_ts commit -m "refactor: drop retired AI scene labels"
```

Expected: one frontend commit.

---

## Task 7: Sync active docs and migration truth

**Files:**

- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/basic-admin-smoke.ps1`

- [ ] **Step 1: Update current status**

Add or update an AI row in `docs/migration/current-status.md` with this meaning:

```text
AI core migration preparation: implemented for prune only. AI goods and AI cine are removed from active scope; their module-owned tables and menu permissions are deleted by 20260508_remove_ai_goods_cine_modules.sql. Core AI remains legacy PHP-backed and not yet migrated to Go REST. AI streaming remains planned over WebSocket.
```

- [ ] **Step 2: Update API contract**

In `docs/contracts/admin-api-v1.md`, add an AI migration note:

```text
AI goods/cine are removed product modules. Active AI Go contracts must not define /api/admin/v1/ai-goods, /api/admin/v1/ai-cine, /api/admin/Goods, or /api/admin/Cine adapters. Core AI migration starts from models/tools/prompts/agents/knowledge/chat/runs after the prune migration is applied.
```

- [ ] **Step 3: Update smoke gate**

In `admin_back_go/scripts/basic-admin-smoke.ps1`, add a `users/init` assertion that fails if `/ai/goods` or `/ai/cine` appears and fails if retained AI core routes `/ai/models` or `/ai/chat` disappear.

In `docs/testing/smoke-matrix.md`, record the same gate:

```text
users/init must not return /ai/goods or /ai/cine; AI core menu entries /ai/models and /ai/chat must still be present for authorized roles. The migration still intentionally leaves Redis/operator-side cache clearing outside SQL.
```

- [ ] **Step 4: Update backend architecture**

In `admin_back_go/docs/architecture.md`, document:

```text
AI product modules goods/cine are retired before Go AI migration. Go AI runtime must not depend on goods/cine schemas or upload folders. ai_run_timeout remains an active legacy cron fact until replaced by a Go task type.
```

- [ ] **Step 5: Run docs residue checks**

```powershell
rg -n "ai_goods|ai_cine|/ai/goods|/ai/cine|goods_tts|cine_keyframes|Goods/init|Cine/init" E:\admin_go\docs E:\admin_go\admin_back_go\docs E:\admin_go\admin_back_go\internal E:\admin_go\admin_front_ts\src E:\admin_go\admin_front_ts\tests
```

Expected: no active contract/code hits. Historical `docs/superpowers/specs` or `docs/superpowers/plans` may mention old terms only if they are clearly historical.

- [ ] **Step 6: Commit docs**

```powershell
git -C E:\admin_go add docs/migration/current-status.md docs/testing/smoke-matrix.md docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: mark retired AI product modules removed"
git -C E:\admin_go\admin_back_go add docs/architecture.md scripts/basic-admin-smoke.ps1
git -C E:\admin_go\admin_back_go commit -m "docs: record AI prune boundary"
```

Expected: root docs and backend docs commits are separate.

---

## Task 8: Final verification gate

**Files:** no source changes

- [ ] **Step 1: Backend verification**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: all exit 0.

- [ ] **Step 2: Frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/ai/agent-helpers.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false
git diff --check
```

Expected: all exit 0.

- [ ] **Step 3: DB post-migration verification**

Run the SQL from Task 3 again. Expected values:

```text
table_left = 0
permission_left = 0
active_quick_entry_left = 0
active_scene_left = 0
active_scene_agent_left = 0
active_cine_tool_left = 0
```

- [ ] **Step 4: Smoke with users/init prune gate**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected smoke facts:

```text
users/init does not contain /ai/goods
users/init does not contain /ai/cine
users/init still contains retained AI entries such as /ai/models and /ai/chat when the role is authorized
login/auth/RBAC/payment smoke remains healthy
```

- [ ] **Step 5: Final residue sweep**

```powershell
rg -n "ai_goods|ai_cine|/ai/goods|/ai/cine|src/api/ai/goods|src/api/ai/cine|goods_tts|cine_keyframes|cine_generate_keyframe|goods_script|cine_project|cine_keyframe" E:\admin_go\admin_back_go E:\admin_go\admin_front_ts E:\admin_go\docs -g "!runtime/**" -g "!docs/superpowers/**"
```

Expected: no active code/contract hits. If docs history under `docs/superpowers/**` contains old terms, leave it as historical evidence.

---

## Task 9: Handoff to AI core migration P1

**Files:** no source changes

- [ ] **Step 1: Record next P1 boundaries**

Create the next spec only after Phase 0 passes final verification. P1 scope:

```text
Go REST for ai_models, ai_tools, ai_prompts only.
No chat runtime in P1.
No goods/cine adapter.
Canonical prompt table decision: ai_prompts is expected canonical; ai_prompt needs a diff/merge decision before drop.
```

- [ ] **Step 2: Keep current plan closed**

Do not mark AI core implemented in `current-status`. The correct wording after this plan is:

```text
AI prune implemented; AI core Go migration planned next.
```

## Self-review

- Spec coverage: every Phase 0 requirement in the design has a task: DB prune, upload enum/docs, frontend deletion, docs sync, verification, handoff.
- Placeholder scan: this plan contains no undefined file path, no vague error handling instruction, and no open-ended deletion rule.
- Compatibility check: hard deletes are limited to module-owned tables and menu/grant rows; AI core history rows are soft-deleted or retained.
