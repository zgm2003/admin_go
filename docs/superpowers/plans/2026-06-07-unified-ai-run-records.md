# Unified AI Run Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Admin chat, Canvas text, Admin/Canvas image generation, and Canvas video generation all write one consistent AI run record without restoring old billing.

**Architecture:** `internal/module/ai/run` becomes the write owner for `ai_runs` / `ai_run_events`. Chat/image/video keep their own domain tables and call a small recorder around provider boundaries. Admin run monitor keeps the same routes and renders chat plus non-chat rows from one table.

**Tech Stack:** Go, Gin, GORM, MySQL migrations, Vue 3 TypeScript, Vitest, existing PowerShell gates.

---

## Scope and constraints

- Main project role: `api-contract`.
- No `ai_billing_records` resurrection; Canvas generation remains free.
- No fake `ai_conversations` or `ai_messages` for image/video/text rows.
- No fallback fields: every new column must have an explicit producer and consumer. Do not add `cost` or `usage_json`; current provider clients do not produce source-backed values that the monitor consumes.
- Do not use permanent DB defaults to hide missing service values. Migrations may add nullable columns, backfill existing rows, then modify them to `NOT NULL`.
- `source_id` must be `NOT NULL` and must point to a real source row for every run. Canvas text gets `ai_text_tasks`; a null source is invalid.
- Preserve `/api/admin/v1/ai-runs*` URLs and existing Admin chat rows.
- TDD: each runtime task starts with a failing test, verifies RED, adds minimal code, verifies GREEN.

## File structure map

- Create: `admin_back_go/database/migrations/20260607_unified_ai_run_records.sql` — migration for `ai_runs`, `ai_text_tasks`, and `ai_image_tasks.platform`.
- Create: `admin_back_go/internal/architecture/ai_run_records_schema_test.go` — migration/source guard.
- Modify: `admin_back_go/internal/shared/enum/ai.go` and `internal/shared/dict/dict.go` — modality/source options.
- Create: `admin_back_go/internal/module/ai/run/recorder.go`, `recorder_repository.go`, `recorder_test.go` — unified writer.
- Modify: `admin_back_go/internal/module/ai/run/{model,dto,repository,service}.go` — monitor API fields and filters.
- Create: `admin_back_go/internal/module/ai/text/{model,repository,service,test}.go` if a separate text source helper is cleaner than placing the small source writer in `ai/chat`.
- Modify: `admin_back_go/internal/module/ai/chat/{dto,service,service_test}.go` — Admin chat and Canvas text recording.
- Modify: `admin_back_go/internal/infra/ai/{types.go,image.go,openaicompat/client.go,imagecompat/client.go,imagecompat/client_test.go}` — explicit usage status from provider clients.
- Modify: `admin_back_go/internal/module/ai/image/{model,dto,repository,service,service_test}.go` — image platform and run lifecycle.
- Modify: `admin_back_go/internal/module/ai/video/{dto,repository,service,service_test}.go` — video run lifecycle.
- Modify: `admin_back_go/internal/bootstrap/{app.go,worker.go}` — recorder wiring.
- Modify: `admin_front_ts/src/api/ai/runs.ts`, `src/views/Main/ai/runs/components/RunList/index.vue`, `src/i18n/locales/{zh-CN,en-US}.ts` — Admin UI.
- Create: `admin_front_ts/tests/shared/ai/ai-run-unified-records.test.ts` — frontend guard.
- Modify after verification: `docs/contracts/admin-api-v1.md`, `docs/status/current-status.md`, `docs/status/module-matrix.md`, `admin_back_go/docs/architecture.md`.

---

### Task 1: Add schema contract for unified AI runs

**Files:**
- Create: `admin_back_go/database/migrations/20260607_unified_ai_run_records.sql`
- Create: `admin_back_go/internal/architecture/ai_run_records_schema_test.go`
- Modify: `admin_back_go/internal/module/ai/run/model.go`
- Modify: `admin_back_go/internal/module/ai/image/model.go`

- [ ] **Step 1: Write the failing schema guard**

Create `admin_back_go/internal/architecture/ai_run_records_schema_test.go`:

```go
package architecture

import (
    "os"
    "strings"
    "testing"
)

func TestUnifiedAIRunMigrationShape(t *testing.T) {
    body, err := os.ReadFile("../../database/migrations/20260607_unified_ai_run_records.sql")
    if err != nil { t.Fatalf("read migration: %v", err) }
    sql := string(body)
    required := []string{
        "ADD COLUMN `platform` VARCHAR(32) NULL",
        "ADD COLUMN `modality` VARCHAR(32) NULL",
        "ADD COLUMN `source_type` VARCHAR(64) NULL",
        "ADD COLUMN `source_id` BIGINT UNSIGNED NULL",
        "ADD COLUMN `input_snapshot` MEDIUMTEXT NULL",
        "ADD COLUMN `usage_status` VARCHAR(16) NULL",
        "MODIFY COLUMN `platform` VARCHAR(32) NOT NULL",
        "MODIFY COLUMN `modality` VARCHAR(32) NOT NULL",
        "MODIFY COLUMN `source_type` VARCHAR(64) NOT NULL",
        "MODIFY COLUMN `source_id` BIGINT UNSIGNED NOT NULL",
        "MODIFY COLUMN `input_snapshot` MEDIUMTEXT NOT NULL",
        "MODIFY COLUMN `usage_status` VARCHAR(16) NOT NULL",
        "CONSTRAINT `chk_ai_runs_usage_status` CHECK (`usage_status` IN ('pending', 'reported', 'unavailable'))",
        "MODIFY COLUMN `conversation_id` INT UNSIGNED NULL",
        "MODIFY COLUMN `user_message_id` BIGINT UNSIGNED NULL",
        "CREATE TABLE `ai_text_tasks`",
        "CREATE UNIQUE INDEX `uk_ai_runs_source_request`",
    }
    for _, want := range required {
        if !strings.Contains(sql, want) { t.Fatalf("migration missing %q", want) }
    }
    for _, bad := range []string{"ai_billing_records", "ai_billing_rules", "usage_json", "`cost` DECIMAL"} {
        if strings.Contains(sql, bad) { t.Fatalf("migration must not restore %q", bad) }
    }
}
```

- [ ] **Step 2: Run guard to verify RED**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/architecture -run TestUnifiedAIRunMigrationShape -count=1 -p=1
```

Expected: FAIL because the migration does not exist.

- [ ] **Step 3: Add migration**

Create `admin_back_go/database/migrations/20260607_unified_ai_run_records.sql`:

```sql
ALTER TABLE `ai_runs`
  ADD COLUMN `platform` VARCHAR(32) NULL AFTER `id`,
  ADD COLUMN `modality` VARCHAR(32) NULL AFTER `platform`,
  ADD COLUMN `source_type` VARCHAR(64) NULL AFTER `modality`,
  ADD COLUMN `source_id` BIGINT UNSIGNED NULL AFTER `source_type`,
  ADD COLUMN `input_snapshot` MEDIUMTEXT NULL AFTER `model_display_name`,
  ADD COLUMN `usage_status` VARCHAR(16) NULL AFTER `total_tokens`;

UPDATE `ai_runs` r
JOIN `ai_messages` m ON m.id = r.user_message_id
SET
  r.`platform` = 'admin',
  r.`modality` = 'chat',
  r.`source_type` = 'ai_chat_message',
  r.`source_id` = r.`user_message_id`,
  r.`input_snapshot` = m.`content`,
  -- Stored token counts are the only old-row evidence of provider usage; do not infer usage from prompt text or model name.
  r.`usage_status` = IF((r.`prompt_tokens` + r.`completion_tokens` + r.`total_tokens`) > 0, 'reported', 'unavailable');

ALTER TABLE `ai_runs`
  MODIFY COLUMN `platform` VARCHAR(32) NOT NULL,
  MODIFY COLUMN `modality` VARCHAR(32) NOT NULL,
  MODIFY COLUMN `source_type` VARCHAR(64) NOT NULL,
  MODIFY COLUMN `source_id` BIGINT UNSIGNED NOT NULL,
  MODIFY COLUMN `input_snapshot` MEDIUMTEXT NOT NULL,
  MODIFY COLUMN `usage_status` VARCHAR(16) NOT NULL,
  MODIFY COLUMN `conversation_id` INT UNSIGNED NULL COMMENT 'ai_conversations.id; chat rows only',
  MODIFY COLUMN `user_message_id` BIGINT UNSIGNED NULL COMMENT '本轮用户消息ID; chat rows only';

CREATE INDEX `idx_ai_runs_platform_modality_created` ON `ai_runs` (`platform`, `modality`, `created_at`, `id`);
CREATE INDEX `idx_ai_runs_source` ON `ai_runs` (`source_type`, `source_id`, `created_at`, `id`);
CREATE UNIQUE INDEX `uk_ai_runs_source_request` ON `ai_runs` (`source_type`, `source_id`, `request_id`);

CREATE TABLE `ai_text_tasks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `platform` VARCHAR(32) NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `agent_id` BIGINT UNSIGNED NOT NULL,
  `provider_id` BIGINT UNSIGNED NOT NULL,
  `model_id` VARCHAR(191) NOT NULL,
  `prompt` MEDIUMTEXT NOT NULL,
  `answer` MEDIUMTEXT NULL,
  `status` VARCHAR(16) NOT NULL,
  `error_message` VARCHAR(1024) NULL,
  `started_at` DATETIME NULL,
  `finished_at` DATETIME NULL,
  `elapsed_ms` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ai_text_tasks_user_created` (`user_id`, `created_at`, `id`),
  KEY `idx_ai_text_tasks_status_created` (`status`, `created_at`, `id`)
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI文本生成任务';

ALTER TABLE `ai_image_tasks` ADD COLUMN `platform` VARCHAR(32) NULL AFTER `id`;
UPDATE `ai_image_tasks` SET `platform` = 'admin' WHERE `platform` IS NULL;
ALTER TABLE `ai_image_tasks` MODIFY COLUMN `platform` VARCHAR(32) NOT NULL;
CREATE INDEX `idx_ai_image_tasks_platform_created` ON `ai_image_tasks` (`platform`, `created_at`, `id`);

ALTER TABLE `ai_runs`
  ADD CONSTRAINT `chk_ai_runs_usage_status` CHECK (`usage_status` IN ('pending', 'reported', 'unavailable'));
```

- [ ] **Step 4: Update models**

In `ai/run/model.go`, add `Platform`, `Modality`, `SourceType`, `SourceID`, `InputSnapshot`, and `UsageStatus`; make `ConversationID` and `UserMessageID` pointers. In `ai/image/model.go`, add `Platform string` after `ID`.

- [ ] **Step 5: Run guard to verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/architecture -run TestUnifiedAIRunMigrationShape -count=1 -p=1
```

Expected: PASS.

---

### Task 2: Add AI run recorder write owner

**Files:**
- Modify: `admin_back_go/internal/shared/enum/ai.go`
- Modify: `admin_back_go/internal/shared/dict/dict.go`
- Create: `admin_back_go/internal/module/ai/run/recorder.go`
- Create: `admin_back_go/internal/module/ai/run/recorder_repository.go`
- Create: `admin_back_go/internal/module/ai/run/recorder_test.go`

- [ ] **Step 1: Write recorder tests**

Create `admin_back_go/internal/module/ai/run/recorder_test.go` with tests for start validation and usage completion:

```go
func TestRecorderStartsUnifiedImageRun(t *testing.T) {
    repo := &fakeRecorderRepository{nextID: 9}
    svc := NewRecorder(repo, func() time.Time { return time.Date(2026, 6, 7, 1, 2, 3, 0, time.UTC) })
    sourceID := uint64(77)
    id, err := svc.Start(context.Background(), StartInput{Platform: "canvas", Modality: enum.AIRunModalityImage, SourceType: enum.AIRunSourceImageTask, SourceID: sourceID, RequestID: "image-77", UserID: 5, AgentID: 8, ProviderID: 9, ModelID: "gpt-image-1", ModelDisplayName: "GPT Image", InputSnapshot: "cat"})
    if err != nil || id != 9 { t.Fatalf("start failed id=%d err=%v", id, err) }
    if repo.started.Platform != "canvas" || repo.started.SourceID != 77 || repo.started.UsageStatus != enum.AIRunUsagePending { t.Fatalf("bad start record: %#v", repo.started) }
}

func TestRecorderRejectsMissingSourceType(t *testing.T) {
    svc := NewRecorder(&fakeRecorderRepository{}, time.Now)
    _, err := svc.Start(context.Background(), StartInput{Platform: "canvas", Modality: enum.AIRunModalityImage, UserID: 1, AgentID: 1, ProviderID: 1, ModelID: "m"})
    if err == nil { t.Fatalf("expected missing source type error") }
}

func TestRecorderRejectsZeroSourceID(t *testing.T) {
    svc := NewRecorder(&fakeRecorderRepository{}, time.Now)
    _, err := svc.Start(context.Background(), StartInput{Platform: "canvas", Modality: enum.AIRunModalityImage, SourceType: enum.AIRunSourceImageTask, SourceID: 0, UserID: 1, AgentID: 1, ProviderID: 1, ModelID: "m", InputSnapshot: "cat"})
    if err == nil { t.Fatalf("expected zero source id error") }
}

func TestRecorderCompleteKeepsTokenUsageFlag(t *testing.T) {
    repo := &fakeRecorderRepository{}
    svc := NewRecorder(repo, func() time.Time { return time.Date(2026, 6, 7, 2, 0, 0, 0, time.UTC) })
    err := svc.Complete(context.Background(), CompleteInput{RunID: 9, PromptTokens: 3, CompletionTokens: 4, TotalTokens: 7, UsageStatus: enum.AIRunUsageReported, DurationMS: 1200})
    if err != nil { t.Fatalf("complete failed: %v", err) }
    if repo.completed.TotalTokens != 7 || repo.completed.UsageStatus != enum.AIRunUsageReported { t.Fatalf("bad complete record: %#v", repo.completed) }
}
```

- [ ] **Step 2: Run tests to verify RED**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/run -run 'TestRecorder' -count=1 -p=1
```

Expected: FAIL because recorder types do not exist.

- [ ] **Step 3: Add enums and dicts**

Add to `internal/shared/enum/ai.go`:

```go
const (
    AIRunModalityChat = "chat"
    AIRunModalityText = "text"
    AIRunModalityImage = "image"
    AIRunModalityVideo = "video"
    AIRunSourceChatMessage = "ai_chat_message"
    AIRunSourceTextTask = "ai_text_task"
    AIRunSourceImageTask = "ai_image_task"
    AIRunSourceCanvasVideoTask = "canvas_video_task"
    AIRunUsagePending = "pending"
    AIRunUsageReported = "reported"
    AIRunUsageUnavailable = "unavailable"
)
```

Add `AIRunModalityOptions()`, `AIRunSourceTypeOptions()`, and `AIRunUsageStatusOptions()` in `internal/shared/dict/dict.go` using the same loop style as `AIRunStatusOptions()`. Do not reuse `CommonYesNoOptions()` for usage; `pending/reported/unavailable` is a lifecycle state, not a boolean.

- [ ] **Step 4: Add recorder service and repository**

Create `recorder.go` with `StartInput`, `CompleteInput`, `FailInput`, `RunRecorder` validation, and server-generated request IDs. `StartInput.SourceID` is `uint64`, not a pointer; zero is invalid. `Start` writes `usage_status=pending` itself because a started provider attempt has not received terminal usage yet. `CompleteInput` must carry `UsageStatus` as either `reported` or `unavailable`, and `Complete` rejects `pending` for terminal rows. `Fail`, `Cancel`, and `Timeout` write `usage_status=unavailable` because those terminal paths have no provider usage payload. Create `recorder_repository.go` using existing `finishRun(...)` to append terminal events. The repository must start rows in a transaction: insert `ai_runs`, then insert seq=1 `ai_run_events`.

- [ ] **Step 5: Run recorder tests to verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/run -run 'TestRecorder' -count=1 -p=1
```

Expected: PASS.

---

### Task 3: Expand AI run monitor API for non-chat rows

**Files:**
- Modify: `admin_back_go/internal/module/ai/run/dto.go`
- Modify: `admin_back_go/internal/module/ai/run/repository.go`
- Modify: `admin_back_go/internal/module/ai/run/service.go`
- Modify: `admin_back_go/internal/module/ai/run/service_test.go`
- Modify: `admin_back_go/internal/module/ai/run/transport/admin/request.go`

- [ ] **Step 1: Add failing service test for image run detail**

Append to `service_test.go`:

```go
func TestDetailAllowsImageRunWithoutMessages(t *testing.T) {
    sourceID := uint64(77)
    repo := &fakeRepository{run: &RunDetailRow{ID: 9, Platform: "canvas", Modality: enum.AIRunModalityImage, SourceType: enum.AIRunSourceImageTask, SourceID: sourceID, RequestID: "ai_image_task-77", UserID: 7, Username: "canvas-user", AgentID: 8, AgentName: "image agent", ProviderID: 3, ProviderName: "OpenAI", Status: enum.AIRunStatusSuccess, ModelID: "gpt-image-1", InputSnapshot: "cat", UsageStatus: enum.AIRunUsageReported, TotalTokens: 11}}
    res, appErr := NewService(repo).Detail(context.Background(), 9)
    if appErr != nil { t.Fatalf("detail failed: %v", appErr) }
    if res.Platform != "canvas" || res.Modality != enum.AIRunModalityImage || res.SourceID != 77 || res.UserMessage != nil || res.AssistantMessage != nil { t.Fatalf("bad detail: %#v", res) }
}
```

- [ ] **Step 2: Run test to verify RED**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/run -run TestDetailAllowsImageRunWithoutMessages -count=1 -p=1
```

Expected: FAIL because monitor DTOs lack the new fields.

- [ ] **Step 3: Extend DTO, repository, request, and page-init**

Add `platform`, `modality`, `source_type` filters to list/stats request structs. Add these response fields to list/detail items:

```go
Platform string `json:"platform"`
Modality string `json:"modality"`
SourceType string `json:"source_type"`
SourceID uint64 `json:"source_id"`
InputSnapshot string `json:"input_snapshot"`
UsageStatus string `json:"usage_status"`
```

Also change chat-only response fields such as `ConversationID` to pointer types where the database column is nullable. A non-chat row must return `conversation_id:null`; it must not leak `0` as a fake conversation id.

Repository select clauses must include:

```sql
r.platform, r.modality, r.source_type, r.source_id, r.input_snapshot, r.usage_status
```

Filter code:

```go
if strings.TrimSpace(query.Platform) != "" { db = db.Where("r.platform = ?", strings.TrimSpace(query.Platform)) }
if strings.TrimSpace(query.Modality) != "" { db = db.Where("r.modality = ?", strings.TrimSpace(query.Modality)) }
if strings.TrimSpace(query.SourceType) != "" { db = db.Where("r.source_type = ?", strings.TrimSpace(query.SourceType)) }
```

Page-init must include platform, modality, and source type option arrays.

- [ ] **Step 4: Run AI run tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/run -count=1 -p=1
```

Expected: PASS.

---

### Task 4: Record Admin chat and Canvas text through recorder

**Files:**
- Modify: `admin_back_go/internal/module/ai/chat/dto.go`
- Modify: `admin_back_go/internal/module/ai/chat/service.go`
- Modify: `admin_back_go/internal/module/ai/chat/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Add failing Canvas text run test**

Append to `chat/service_test.go`:

```go
func TestCanvasCompletionRecordsRun(t *testing.T) {
    repo := &fakeRepository{agent: validCanvasTextAgent(), nextTextTaskID: 77}
    recorder := &fakeRunRecorder{}
    engine := &fakeEngine{result: &infraai.ChatResult{Answer: "ok", PromptTokens: 2, CompletionTokens: 3, TotalTokens: 5, UsageStatus: infraai.UsageStatusReported}}
    service := NewService(Dependencies{Repository: repo, EngineFactory: fakeEngineFactory{engine: engine}, Secretbox: testSecretBox(), RunRecorder: recorder, Now: fixedNow})
    res, appErr := service.CanvasCompletion(context.Background(), CanvasCompletionInput{UserID: 7, AgentID: 8, Message: "draw a cat"})
    if appErr != nil || res == nil || res.Content != "ok" { t.Fatalf("completion failed res=%#v err=%v", res, appErr) }
    if repo.textTask.Prompt != "draw a cat" || recorder.started.SourceID != 77 || recorder.started.Platform != enum.PlatformCanvas || recorder.started.Modality != enum.AIRunModalityText || recorder.started.SourceType != enum.AIRunSourceTextTask || recorder.completed.TotalTokens != 5 || recorder.completed.UsageStatus != enum.AIRunUsageReported { t.Fatalf("run not recorded: %#v %#v", recorder.started, recorder.completed) }
}
```

- [ ] **Step 2: Run test to verify RED**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/chat -run TestCanvasCompletionRecordsRun -count=1 -p=1
```

Expected: FAIL because chat service has no recorder dependency.

- [ ] **Step 3: Add recorder dependency and Canvas text lifecycle**

Add a `RunRecorder` interface and a text task repository dependency to `chat/dto.go`, inject them into `Service`, and in `CanvasCompletion` create the source row before the run:

```go
startedAt := s.now()
textTask, err := s.textTasks.Create(ctx, aitext.CreateInput{Platform: enum.PlatformCanvas, UserID: input.UserID, AgentID: agent.AgentID, ProviderID: agent.ProviderID, ModelID: agent.ModelID, Prompt: input.Message, Status: aitext.StatusRunning, StartedAt: startedAt, CreatedAt: startedAt, UpdatedAt: startedAt})
if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.text_task_failed", nil, "创建Canvas文本任务失败", err) }
runID, err := s.runRecorder.Start(ctx, airun.StartInput{Platform: enum.PlatformCanvas, Modality: enum.AIRunModalityText, SourceType: enum.AIRunSourceTextTask, SourceID: textTask.ID, UserID: input.UserID, AgentID: int64(agent.AgentID), ProviderID: int64(agent.ProviderID), ModelID: agent.ModelID, ModelDisplayName: agent.ModelDisplayName, InputSnapshot: textTask.Prompt})
if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.run_start_failed", nil, "创建Canvas文本运行记录失败", err) }
```

Complete the text task and run after provider success with provider token totals and `result.UsageStatus`. Fail both rows on provider error. If `result.UsageStatus` is empty or not one of `reported/unavailable`, return an internal error and do not silently mark it as unavailable. Do not change Canvas response shape.

Also add explicit provider usage status to `infra/ai/types.go` and the OpenAI-compatible chat client:

```go
const (
    UsageStatusReported = "reported"
    UsageStatusUnavailable = "unavailable"
)

type ChatResult struct {
    // existing fields...
    UsageStatus string
}
```

`openaicompat/client.go` sets `UsageStatusReported` when a stream chunk contains `usage`; it sets `UsageStatusUnavailable` when the stream ends without usage. The chat service must validate this field before completing the run.

- [ ] **Step 4: Move Admin chat write calls to recorder**

Replace direct `repo.CreateRun`, `repo.CompleteRun`, and `repo.FinishRun` in `ConversationReply` with recorder calls. Use:

```go
Platform: enum.PlatformAdmin
Modality: enum.AIRunModalityChat
SourceType: enum.AIRunSourceChatMessage
SourceID: uint64(input.UserMessageID)
ConversationID: uintPtrFromInt64(input.ConversationID)
UserMessageID: uintPtrFromInt64(input.UserMessageID)
RequestID: input.RequestID
```

- [ ] **Step 5: Wire recorder in bootstrap and run tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/chat ./internal/bootstrap -count=1 -p=1
```

Expected: PASS.

---

### Task 5: Parse image usage and record Admin/Canvas image runs

**Files:**
- Modify: `admin_back_go/internal/infra/ai/image.go`
- Modify: `admin_back_go/internal/infra/ai/imagecompat/client.go`
- Modify: `admin_back_go/internal/infra/ai/imagecompat/client_test.go`
- Modify: `admin_back_go/internal/module/ai/image/{model,dto,repository,service,service_test}.go`
- Modify: `admin_back_go/internal/bootstrap/{app.go,worker.go}`

- [ ] **Step 1: Add failing image usage parser assertion**

In `imagecompat/client_test.go`, after the complete JSON response test result:

```go
if result.TotalTokens != 1 || result.PromptTokens != 0 || result.CompletionTokens != 0 || result.UsageStatus != infraai.UsageStatusReported { t.Fatalf("usage not parsed: %#v", result) }
```

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/infra/ai/imagecompat -run TestClientGenerateImagesParsesCompleteJSONBeforeConnectionClose -count=1 -p=1
```

Expected: FAIL because `ImageResult` has no token fields.

- [ ] **Step 2: Add image usage fields and parser**

Add to `infra/ai/image.go`:

```go
PromptTokens int
CompletionTokens int
TotalTokens int
UsageStatus string
```

Parse `usage.prompt_tokens`, `usage.completion_tokens`, and `usage.total_tokens` in `imagecompat/client.go`. Set `UsageStatus=infraai.UsageStatusReported` only when the provider response contains a `usage` object. Set `UsageStatus=infraai.UsageStatusUnavailable` when the provider response completes successfully without a `usage` object. Do not infer tokens from image count or model name.

- [ ] **Step 3: Add failing image service run test**

Append to `image/service_test.go`:

```go
func TestExecuteGenerateRecordsImageRun(t *testing.T) {
    box := testImageSecretBox()
    task := validPendingTask(); task.Platform = enum.PlatformCanvas
    engine := &fakeImageEngine{result: &infraai.ImageResult{Images: []infraai.GeneratedImage{{URL: "https://cdn.test/out.png", MimeType: "image/png"}}, TotalTokens: 17, UsageStatus: infraai.UsageStatusReported}}
    recorder := &fakeImageRunRecorder{}
    repo := &fakeImageRepository{agent: validImageAgent(t, box), task: &task, claimTask: true, nextAssetID: 501}
    service := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeImageEngineFactory{engine: engine}, RunRecorder: recorder, Now: fixedImageNow()})
    result, err := service.ExecuteGenerate(context.Background(), GenerateInput{TaskID: task.ID, UserID: task.UserID})
    if err != nil || result == nil || result.Status != StatusSuccess { t.Fatalf("generate failed result=%#v err=%v", result, err) }
    if recorder.started.Platform != enum.PlatformCanvas || recorder.started.Modality != enum.AIRunModalityImage || recorder.started.SourceType != enum.AIRunSourceImageTask || recorder.completed.TotalTokens != 17 || recorder.completed.UsageStatus != enum.AIRunUsageReported { t.Fatalf("image run not recorded") }
}
```

- [ ] **Step 4: Implement image lifecycle**

Persist `ImageTask.Platform` from `CreateInput.Platform`. In `ExecuteGenerate`, after claim and before `GenerateImages`, call recorder start with `source_type=ai_image_task` and `source_id=task.ID`. After output persistence and task success, complete the run with `result.UsageStatus`. On failure after run start, fail the run and finish the task failed with `usage_status=unavailable`. If recorder start fails, mark task failed and do not call provider.

- [ ] **Step 5: Run image tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/infra/ai/imagecompat ./internal/module/ai/image -count=1 -p=1
```

Expected: PASS.

---

### Task 6: Record Canvas video runs

**Files:**
- Modify: `admin_back_go/internal/module/ai/video/{dto,repository,service,service_test}.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Add failing video run test**

Append to `video/service_test.go`:

```go
func TestCreateRecordsCanvasVideoRun(t *testing.T) {
    box := testVideoSecretBox()
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box), nextTaskID: 77}
    recorder := &fakeVideoRunRecorder{}
    engine := &fakeVideoEngine{createTask: &infraai.VideoTask{ID: "provider-task-1", Status: "running"}}
    service := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeVideoEngineFactory{engine: engine}, RunRecorder: recorder, Now: fixedVideoNow})
    result, appErr := service.Create(context.Background(), CreateInput{UserID: 7, AgentID: 8, Prompt: "cat", DurationSeconds: 5})
    if appErr != nil || result == nil || result.ID != 77 { t.Fatalf("create failed result=%#v err=%v", result, appErr) }
    if recorder.started.Platform != enum.PlatformCanvas || recorder.started.Modality != enum.AIRunModalityVideo || recorder.started.SourceType != enum.AIRunSourceCanvasVideoTask { t.Fatalf("video run not started: %#v", recorder.started) }
}
```

- [ ] **Step 2: Run test to verify RED**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/video -run TestCreateRecordsCanvasVideoRun -count=1 -p=1
```

Expected: FAIL because video service has no recorder dependency.

- [ ] **Step 3: Implement video lifecycle**

Add a recorder dependency. After local task creation and before `engine.CreateVideo`, start a run with `platform=canvas`, `modality=video`, `source_type=canvas_video_task`, `source_id=canvas_video_tasks.id`; recorder start writes `usage_status=pending`. If provider create fails, mark task failed and fail the run with `usage_status=unavailable`. When `Status` observes provider terminal status, update task and run together: completed -> run success with `usage_status=unavailable` unless the provider status payload has real usage, failed -> run failed with `usage_status=unavailable`, cancelled -> run canceled with `usage_status=unavailable`.

- [ ] **Step 4: Run video tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/module/ai/video -count=1 -p=1
```

Expected: PASS.

---

### Task 7: Update Admin Vue run monitor contract and UI

**Files:**
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-run-unified-records.test.ts`

- [ ] **Step 1: Write failing frontend source guard**

Create `admin_front_ts/tests/shared/ai/ai-run-unified-records.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(__dirname, '../../..')
const runsApi = readFileSync(resolve(root, 'src/api/ai/runs.ts'), 'utf8')
const runList = readFileSync(resolve(root, 'src/views/Main/ai/runs/components/RunList/index.vue'), 'utf8')
const zh = readFileSync(resolve(root, 'src/i18n/locales/zh-CN.ts'), 'utf8')
const en = readFileSync(resolve(root, 'src/i18n/locales/en-US.ts'), 'utf8')

describe('unified AI run records frontend contract', () => {
  it('exposes platform, modality, and source filters', () => {
    expect(runsApi).toContain('platform?:')
    expect(runsApi).toContain('modality?:')
    expect(runsApi).toContain('source_type?:')
    expect(runsApi).toContain('platform: params.platform')
    expect(runsApi).toContain('modality: params.modality')
    expect(runsApi).toContain('source_type: params.source_type')
  })

  it('renders non-chat source fields without requiring messages', () => {
    expect(runList).toContain('aiRuns.fields.modality')
    expect(runList).toContain('aiRuns.fields.sourceType')
    expect(runList).toContain('aiRuns.fields.inputSnapshot')
    expect(runList).toContain('aiRuns.fields.usageStatus')
    expect(runList).not.toContain('detailData.user_message!.content')
    expect(runList).not.toContain('detailData.assistant_message!.content')
  })

  it('adds bilingual labels', () => {
    for (const key of ['modality', 'sourceType', 'inputSnapshot', 'usageStatus', 'platform']) {
      expect(zh).toContain(key)
      expect(en).toContain(key)
    }
  })
})
```

- [ ] **Step 2: Run frontend test to verify RED**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-run-unified-records.test.ts
```

Expected: FAIL because the new filters and labels are absent.

- [ ] **Step 3: Extend API types and query normalization**

In `src/api/ai/runs.ts`, add:

```ts
export type AiRunModality = 'chat' | 'text' | 'image' | 'video'
export type AiRunUsageStatus = 'pending' | 'reported' | 'unavailable'
```

Add to params and item/detail interfaces:

```ts
platform?: string
modality?: AiRunModality | ''
source_type?: string
source_id: number
input_snapshot: string
usage_status: AiRunUsageStatus
conversation_id: number | null
user_message: AiRunMessageSummary | null
assistant_message: AiRunMessageSummary | null
```

Add normalization lines:

```ts
if (params.platform) query.platform = params.platform
if (params.modality) query.modality = params.modality
if (params.source_type) query.source_type = params.source_type
```

- [ ] **Step 4: Render fields and avoid message non-null assertions**

In `RunList/index.vue`, add platform/modality/source columns and detail rows. Render chat messages only when present:

```ts
const hasUserMessage = computed(() => detailData.value !== null && detailData.value.user_message !== null)
const hasAssistantMessage = computed(() => detailData.value !== null && detailData.value.assistant_message !== null)
const inputSnapshot = computed(() => {
  const detail = detailData.value
  if (detail === null) return ''
  return detail.input_snapshot.trim()
})
```

- [ ] **Step 5: Add i18n labels**

Add these under `aiRuns.fields`:

```ts
platform: '平台',
modality: '类型',
sourceType: '来源类型',
sourceId: '来源ID',
inputSnapshot: '输入快照',
usageStatus: '用量状态',
```

English:

```ts
platform: 'Platform',
modality: 'Modality',
sourceType: 'Source Type',
sourceId: 'Source ID',
inputSnapshot: 'Input Snapshot',
usageStatus: 'Usage Status',
```

- [ ] **Step 6: Run frontend targeted tests**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-run-unified-records.test.ts tests/shared/ai/ai-image-api.test.ts
npm run typecheck -- --noEmit
```

Expected: all commands exit 0.

---

### Task 8: Update contracts, status, and verification evidence

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update contract docs**

In `docs/contracts/admin-api-v1.md`, document:

```text
AI run monitor covers provider attempts across chat/text/image/video. Existing /api/admin/v1/ai-runs* routes remain stable. Optional filters: platform, modality, source_type. Non-chat rows return user_message:null and assistant_message:null by design, with input_snapshot/source_type/source_id identifying the domain source and usage_status describing pending/reported/unavailable provider usage. Canvas free-generation remains free and does not write ai_billing_records.
```

- [ ] **Step 2: Update backend architecture docs**

In `admin_back_go/docs/architecture.md`, replace the token-only run monitor wording with:

```text
internal/module/ai/run owns ai_runs / ai_run_events as the unified provider-attempt monitor for chat/text/image/video. Chat rows may link ai_conversations and ai_messages; image/video/text rows use source_type/source_id and input_snapshot instead of fake messages. usage_status is pending while running and becomes reported or unavailable only from provider result handling.
```

- [ ] **Step 3: Update status docs only after tests pass**

Add a verified entry to `docs/status/current-status.md` only after backend/frontend/root gates pass:

```text
2026-06-07 Unified AI run records verified: Admin chat, Canvas text, Admin/Canvas image, and Canvas video provider attempts now write ai_runs through internal/module/ai/run recorder; ai_runs supports platform/modality/source/input_snapshot/usage_status fields, non-chat rows do not fake ai_messages, Canvas free-generation still does not write ai_billing_records; backend targeted tests, Admin Vue targeted tests/typecheck, runtime doc facts, and governance checks passed.
```

- [ ] **Step 4: Run backend targeted tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./internal/architecture ./internal/shared/enum ./internal/shared/dict ./internal/module/ai/run ./internal/module/ai/chat ./internal/module/ai/image ./internal/module/ai/video ./internal/infra/ai/imagecompat ./internal/bootstrap ./internal/server -count=1 -p=1
```

Expected: PASS.

- [ ] **Step 5: Run frontend targeted tests**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-run-unified-records.test.ts tests/shared/ai/ai-image-api.test.ts
npm run typecheck -- --noEmit
```

Expected: PASS.

- [ ] **Step 6: Run root governance and contract gates**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: all commands exit 0.

---

## Self-review checklist

- Spec coverage: Tasks 1-2 cover schema and recorder; Tasks 4-6 cover chat/text/image/video; Task 7 covers Admin UI; Task 8 covers contracts/status/verification.
- Compatibility: Existing `/api/admin/v1/ai-runs*` routes stay unchanged; old chat rows are backfilled and remain readable.
- No old billing: migration and tests explicitly reject `ai_billing_*` resurrection.
- Data honesty: non-chat rows use `source_type/source_id/input_snapshot`; no fake conversation/message records.
- TDD: every implementation task starts with a failing test or guard, then minimal production code, then targeted verification.

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-07-unified-ai-run-records.md`.

Two execution options:

1. Subagent-Driven (recommended) - dispatch a fresh subagent per task, review between tasks, fast iteration.
2. Inline Execution - execute tasks in this session using executing-plans, batch execution with checkpoints.
