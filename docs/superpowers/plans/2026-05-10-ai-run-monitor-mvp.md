# AI Run Monitor MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the AI run monitor slice on top of `ai_runs` and `ai_run_events`, recording token-only runtime facts for each chat reply.

**Architecture:** `aimessage` remains the send entry, `aichat` owns runtime write transitions, and `airun` owns read-only monitor APIs. The database stores one run per user message and lifecycle events only; WebSocket delta stays in realtime and final content stays in `ai_messages`.

**Tech Stack:** Go + Gin + GORM + MySQL 8 + existing realtime Publisher; Vue 3 + TypeScript + Element Plus.

---

## Scope Lock

Only this slice is in scope:

```text
运行监控 = ai_runs + ai_run_events + token stats
```

Do not implement:

```text
cost / billing
ai_usage_daily
tool / RAG / run steps
provider task IDs
delta event persistence
```

The migration has already been applied to live DB and created only:

```text
ai_runs
ai_run_events
```

---

## File Structure

### Backend

```text
admin_back_go/database/migrations/20260510_ai_run_monitor_mvp.sql
  - canonical run monitor schema; destructive only for 0-row ai_runs baseline

admin_back_go/internal/enum/ai.go
  - string statuses/events: running/success/failed/canceled/timeout and start/completed/failed/canceled/timeout

admin_back_go/internal/dict/dict.go
  - run status options as string values for frontend filters

admin_back_go/internal/module/aichat/model.go
  - update Run model to new schema

admin_back_go/internal/module/aichat/dto.go
  - add run lifecycle DTOs and repository methods

admin_back_go/internal/module/aichat/repository.go
  - create run, append events, mark terminal states, timeout old runs

admin_back_go/internal/module/aichat/service.go
  - wrap ExecuteConversationReply with run lifecycle writes

admin_back_go/internal/bootstrap/ai_reply_dispatcher.go
  - keep cancel behavior; aichat handles canceled status when context is canceled

admin_back_go/internal/module/airun/*
  - update read monitor DTO/request/repository/service/handler tests to new fields
```

### Frontend

```text
admin_front_ts/src/api/ai/runs.ts
  - replace run_status/model_snapshot/latency/error_msg with status/model_id/model_display_name/duration/error_message

admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue
  - use status string filter and new fields

admin_front_ts/src/views/Main/ai/runs/components/RunStats/index.vue
  - use status dict shape and duration labels
```

### Docs

```text
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Backend enum and dict contract

**Files:**
- Modify: `admin_back_go/internal/enum/ai.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/enum/ai_runtime_test.go`
- Modify: `admin_back_go/internal/dict/ai_runtime_test.go`

- [ ] **Step 1: Replace integer run status enum with string statuses**

In `admin_back_go/internal/enum/ai.go`, replace the current `AIRunStatus*` integer block with:

```go
const (
	AIRunStatusRunning  = "running"
	AIRunStatusSuccess  = "success"
	AIRunStatusFailed   = "failed"
	AIRunStatusCanceled = "canceled"
	AIRunStatusTimeout  = "timeout"
)

var AIRunStatuses = []string{AIRunStatusRunning, AIRunStatusSuccess, AIRunStatusFailed, AIRunStatusCanceled, AIRunStatusTimeout}
var AIRunStatusLabels = map[string]string{AIRunStatusRunning: "运行中", AIRunStatusSuccess: "成功", AIRunStatusFailed: "失败", AIRunStatusCanceled: "已取消", AIRunStatusTimeout: "超时"}

const (
	AIRunEventStart     = "start"
	AIRunEventCompleted = "completed"
	AIRunEventFailed    = "failed"
	AIRunEventCanceled  = "canceled"
	AIRunEventTimeout   = "timeout"
)

var AIRunEvents = []string{AIRunEventStart, AIRunEventCompleted, AIRunEventFailed, AIRunEventCanceled, AIRunEventTimeout}
var AIRunEventLabels = map[string]string{AIRunEventStart: "开始生成", AIRunEventCompleted: "生成完成", AIRunEventFailed: "生成失败", AIRunEventCanceled: "用户停止", AIRunEventTimeout: "运行超时"}
```

Update validators at the bottom:

```go
func IsAIRunStatus(value string) bool { return stringIn(value, AIRunStatuses) }
func IsAIRunEvent(value string) bool  { return stringIn(value, AIRunEvents) }
```

Keep `AIRunStep*` only if other code still references it during this pass; after `airun` no longer returns steps, remove step options in a later cleanup only if residue scan proves no active references.

- [ ] **Step 2: Add string option helper in dict**

In `admin_back_go/internal/dict/dict.go`, change `AIRunStatusOptions()` to:

```go
func AIRunStatusOptions() []Option[string] {
	options := make([]Option[string], 0, len(enum.AIRunStatuses))
	for _, value := range enum.AIRunStatuses {
		options = append(options, Option[string]{Label: enum.AIRunStatusLabels[value], Value: value})
	}
	return options
}
```

- [ ] **Step 3: Update enum tests**

In `admin_back_go/internal/enum/ai_runtime_test.go`, replace run status assertions with:

```go
func TestAIRuntimeRunStatusesAreStable(t *testing.T) {
	if !IsAIRunStatus(AIRunStatusRunning) || !IsAIRunStatus(AIRunStatusSuccess) || !IsAIRunStatus(AIRunStatusFailed) || !IsAIRunStatus(AIRunStatusCanceled) || !IsAIRunStatus(AIRunStatusTimeout) || IsAIRunStatus("queued") {
		t.Fatalf("run status enum mismatch")
	}
	if !IsAIRunEvent(AIRunEventStart) || !IsAIRunEvent(AIRunEventCompleted) || !IsAIRunEvent(AIRunEventFailed) || !IsAIRunEvent(AIRunEventCanceled) || !IsAIRunEvent(AIRunEventTimeout) || IsAIRunEvent("delta") {
		t.Fatalf("run event enum mismatch")
	}
}
```

- [ ] **Step 4: Update dict tests**

In `admin_back_go/internal/dict/ai_runtime_test.go`, assert five string statuses:

```go
func TestAIRunStatusOptionsUseStringValues(t *testing.T) {
	statuses := AIRunStatusOptions()
	if len(statuses) != 5 || statuses[0].Value != enum.AIRunStatusRunning || statuses[4].Value != enum.AIRunStatusTimeout {
		t.Fatalf("unexpected run status options: %#v", statuses)
	}
}
```

- [ ] **Step 5: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict -count=1
```

Expected: both packages pass.

---

## Task 2: aichat runtime writes `ai_runs` and `ai_run_events`

**Files:**
- Modify: `admin_back_go/internal/module/aichat/model.go`
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/repository.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`

- [ ] **Step 1: Update aichat Run model**

Replace old `Run` in `model.go` with fields matching the new table:

```go
type Run struct {
	ID                 int64      `gorm:"column:id;primaryKey"`
	ConversationID     int64      `gorm:"column:conversation_id"`
	RequestID          string     `gorm:"column:request_id"`
	UserMessageID      int64      `gorm:"column:user_message_id"`
	AssistantMessageID *int64     `gorm:"column:assistant_message_id"`
	UserID             int64      `gorm:"column:user_id"`
	AgentID            int64      `gorm:"column:agent_id"`
	ProviderID         int64      `gorm:"column:provider_id"`
	ModelID            string     `gorm:"column:model_id"`
	ModelDisplayName   string     `gorm:"column:model_display_name"`
	Status             string     `gorm:"column:status"`
	PromptTokens       uint       `gorm:"column:prompt_tokens"`
	CompletionTokens   uint       `gorm:"column:completion_tokens"`
	TotalTokens        uint       `gorm:"column:total_tokens"`
	DurationMS         *uint      `gorm:"column:duration_ms"`
	ErrorMessage       string     `gorm:"column:error_message"`
	StartedAt          *time.Time `gorm:"column:started_at"`
	FinishedAt         *time.Time `gorm:"column:finished_at"`
	CreatedAt          time.Time  `gorm:"column:created_at"`
	UpdatedAt          time.Time  `gorm:"column:updated_at"`
}
```

Add:

```go
type RunEvent struct {
	ID        int64     `gorm:"column:id;primaryKey"`
	RunID     int64     `gorm:"column:run_id"`
	Seq       uint      `gorm:"column:seq"`
	EventType string    `gorm:"column:event_type"`
	Message   string    `gorm:"column:message"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

func (RunEvent) TableName() string { return "ai_run_events" }
```

- [ ] **Step 2: Extend repository interface**

In `dto.go`, add:

```go
type CreateRunRecord struct {
	ConversationID   int64
	RequestID        string
	UserMessageID    int64
	UserID           int64
	AgentID          int64
	ProviderID       int64
	ModelID          string
	ModelDisplayName string
	StartedAt        time.Time
}

type CompleteRunRecord struct {
	RunID              int64
	AssistantMessageID int64
	PromptTokens       int
	CompletionTokens   int
	TotalTokens        int
	FinishedAt         time.Time
	DurationMS         uint
}

type FinishRunRecord struct {
	RunID        int64
	Status       string
	Message      string
	FinishedAt   time.Time
	DurationMS   uint
}
```

Add methods to `Repository`:

```go
CreateRun(ctx context.Context, input CreateRunRecord) (int64, error)
CompleteRun(ctx context.Context, input CompleteRunRecord) error
FinishRun(ctx context.Context, input FinishRunRecord) error
```

- [ ] **Step 3: Implement repository lifecycle methods**

In `repository.go`, add helpers:

```go
func (r *GormRepository) CreateRun(ctx context.Context, input CreateRunRecord) (int64, error) {
	if r == nil || r.db == nil {
		return 0, ErrRepositoryNotConfigured
	}
	startedAt := input.StartedAt
	if startedAt.IsZero() {
		startedAt = time.Now()
	}
	run := Run{
		ConversationID:   input.ConversationID,
		RequestID:        input.RequestID,
		UserMessageID:    input.UserMessageID,
		UserID:           input.UserID,
		AgentID:          input.AgentID,
		ProviderID:       input.ProviderID,
		ModelID:          input.ModelID,
		ModelDisplayName: input.ModelDisplayName,
		Status:           enum.AIRunStatusRunning,
		StartedAt:        &startedAt,
	}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&run).Error; err != nil {
			return err
		}
		return tx.Create(&RunEvent{RunID: run.ID, Seq: 1, EventType: enum.AIRunEventStart, Message: enum.AIRunEventLabels[enum.AIRunEventStart]}).Error
	})
	if err != nil {
		return 0, err
	}
	return run.ID, nil
}

func (r *GormRepository) CompleteRun(ctx context.Context, input CompleteRunRecord) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.finishRun(ctx, input.RunID, enum.AIRunStatusSuccess, enum.AIRunEventCompleted, enum.AIRunEventLabels[enum.AIRunEventCompleted], input.FinishedAt, input.DurationMS, map[string]any{
		"assistant_message_id": input.AssistantMessageID,
		"prompt_tokens":        nonNegativeInt(input.PromptTokens),
		"completion_tokens":    nonNegativeInt(input.CompletionTokens),
		"total_tokens":         nonNegativeInt(input.TotalTokens),
	})
}

func (r *GormRepository) FinishRun(ctx context.Context, input FinishRunRecord) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	eventType := enum.AIRunEventFailed
	if input.Status == enum.AIRunStatusCanceled {
		eventType = enum.AIRunEventCanceled
	}
	if input.Status == enum.AIRunStatusTimeout {
		eventType = enum.AIRunEventTimeout
	}
	message := strings.TrimSpace(input.Message)
	if message == "" {
		message = enum.AIRunStatusLabels[input.Status]
	}
	return r.finishRun(ctx, input.RunID, input.Status, eventType, message, input.FinishedAt, input.DurationMS, nil)
}
```

Add the shared private method:

```go
func (r *GormRepository) finishRun(ctx context.Context, runID int64, status string, eventType string, message string, finishedAt time.Time, durationMS uint, extra map[string]any) error {
	if finishedAt.IsZero() {
		finishedAt = time.Now()
	}
	updates := map[string]any{
		"status":        status,
		"finished_at":   finishedAt,
		"duration_ms":   durationMS,
		"error_message": "",
	}
	if status != enum.AIRunStatusSuccess {
		updates["error_message"] = truncateRunMessage(message)
	}
	for key, value := range extra {
		updates[key] = value
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&Run{}).Where("id = ? AND status = ?", runID, enum.AIRunStatusRunning).Updates(updates).Error; err != nil {
			return err
		}
		var maxSeq uint
		if err := tx.Model(&RunEvent{}).Where("run_id = ?", runID).Select("COALESCE(MAX(seq), 0)").Scan(&maxSeq).Error; err != nil {
			return err
		}
		return tx.Create(&RunEvent{RunID: runID, Seq: maxSeq + 1, EventType: eventType, Message: truncateRunMessage(message)}).Error
	})
}

func nonNegativeInt(value int) uint {
	if value < 0 {
		return 0
	}
	return uint(value)
}

func truncateRunMessage(value string) string {
	value = strings.TrimSpace(value)
	runes := []rune(value)
	if len(runes) > 1024 {
		return string(runes[:1024])
	}
	return value
}
```

- [ ] **Step 4: Update TimeoutRuns**

Replace old `TimeoutRuns` with status string logic:

```go
func (r *GormRepository) TimeoutRuns(ctx context.Context, limit int, message string) (int64, error) {
	if r == nil || r.db == nil {
		return 0, ErrRepositoryNotConfigured
	}
	if limit <= 0 {
		limit = defaultTimeoutLimit
	}
	var runs []Run
	if err := r.db.WithContext(ctx).Where("status = ?", enum.AIRunStatusRunning).Order("id ASC").Limit(limit).Find(&runs).Error; err != nil {
		return 0, err
	}
	if len(runs) == 0 {
		return 0, nil
	}
	now := time.Now()
	var changed int64
	for _, run := range runs {
		duration := durationSince(run.StartedAt, now)
		if err := r.FinishRun(ctx, FinishRunRecord{RunID: run.ID, Status: enum.AIRunStatusTimeout, Message: message, FinishedAt: now, DurationMS: duration}); err != nil {
			return changed, err
		}
		changed++
	}
	return changed, nil
}
```

Add:

```go
func durationSince(startedAt *time.Time, finishedAt time.Time) uint {
	if startedAt == nil || startedAt.IsZero() || finishedAt.Before(*startedAt) {
		return 0
	}
	return uint(finishedAt.Sub(*startedAt).Milliseconds())
}
```

- [ ] **Step 5: Wire lifecycle in service**

In `ExecuteConversationReply`, after agent validation and before `publishStart`, create run:

```go
startedAt := s.now()
runID, err := repo.CreateRun(ctx, CreateRunRecord{
	ConversationID:   input.ConversationID,
	RequestID:        input.RequestID,
	UserMessageID:    input.UserMessageID,
	UserID:           input.UserID,
	AgentID:          input.AgentID,
	ProviderID:       int64(agent.ProviderID),
	ModelID:          agent.ModelID,
	ModelDisplayName: agent.ModelDisplayName,
	StartedAt:        startedAt,
})
if err != nil {
	_ = s.publishFailed(ctx, input, "创建AI运行记录失败")
	return nil, err
}
```

On engine/config/history errors after `runID` exists, call:

```go
_ = repo.FinishRun(context.Background(), FinishRunRecord{RunID: runID, Status: statusFromError(ctx, err), Message: msg, FinishedAt: s.now(), DurationMS: durationMS(startedAt, s.now())})
```

On success after assistant message insert:

```go
finishedAt := s.now()
if err := repo.CompleteRun(context.Background(), CompleteRunRecord{RunID: runID, AssistantMessageID: assistantID, PromptTokens: resultTokens(result).Prompt, CompletionTokens: resultTokens(result).Completion, TotalTokens: resultTokens(result).Total, FinishedAt: finishedAt, DurationMS: durationMS(startedAt, finishedAt)}); err != nil {
	_ = s.publishFailed(ctx, input, "更新AI运行记录失败")
	return nil, err
}
```

Add helper functions in `service.go`:

```go
type tokenResult struct{ Prompt, Completion, Total int }

func resultTokens(result *platformai.ChatResult) tokenResult {
	if result == nil {
		return tokenResult{}
	}
	return tokenResult{Prompt: result.PromptTokens, Completion: result.CompletionTokens, Total: result.TotalTokens}
}

func durationMS(startedAt time.Time, finishedAt time.Time) uint {
	if startedAt.IsZero() || finishedAt.Before(startedAt) {
		return 0
	}
	return uint(finishedAt.Sub(startedAt).Milliseconds())
}

func statusFromError(ctx context.Context, err error) string {
	if errors.Is(err, context.Canceled) {
		return enum.AIRunStatusCanceled
	}
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return enum.AIRunStatusTimeout
	}
	return enum.AIRunStatusFailed
}
```

- [ ] **Step 6: Update aichat tests**

Extend fake repository with run tracking fields and methods. Add assertions:

```go
if repo.createdRun.ConversationID != 3 || repo.createdRun.RequestID != "rid" || repo.createdRun.ModelID != "gpt-5.4" {
	t.Fatalf("run was not created correctly: %#v", repo.createdRun)
}
if repo.completedRun.RunID != 100 || repo.completedRun.TotalTokens != 12 || repo.completedRun.AssistantMessageID != 22 {
	t.Fatalf("run was not completed correctly: %#v", repo.completedRun)
}
```

For engine error test, assert:

```go
if repo.finishedRun.Status != enum.AIRunStatusFailed || repo.finishedRun.Message == "" {
	t.Fatalf("run failure not persisted: %#v", repo.finishedRun)
}
```

For cancellation, add a test where engine returns `context.Canceled` and assert `status=canceled`.

- [ ] **Step 7: Run tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat -count=1
```

Expected: pass.

---

## Task 3: airun read monitor on new schema

**Files:**
- Modify: `admin_back_go/internal/module/airun/model.go`
- Modify: `admin_back_go/internal/module/airun/dto.go`
- Modify: `admin_back_go/internal/module/airun/request.go`
- Modify: `admin_back_go/internal/module/airun/repository.go`
- Modify: `admin_back_go/internal/module/airun/service.go`
- Modify: `admin_back_go/internal/module/airun/*_test.go`

- [ ] **Step 1: Replace DTO fields**

Update list/detail DTOs:

```go
Status           string `json:"status"`
StatusName       string `json:"status_name"`
ModelID          string `json:"model_id"`
ModelDisplayName string `json:"model_display_name"`
PromptTokens     uint   `json:"prompt_tokens"`
CompletionTokens uint   `json:"completion_tokens"`
TotalTokens      uint   `json:"total_tokens"`
DurationMS       *uint  `json:"duration_ms"`
DurationText     string `json:"duration_text"`
ErrorMessage     string `json:"error_message"`
```

Remove from active DTOs:

```text
engine_task_id
engine_run_id
run_status
run_status_name
model_snapshot
cost
latency_ms
latency_str
error_msg
usage_json
output_snapshot_json
steps
```

- [ ] **Step 2: Update request query**

In `request.go`, replace `RunStatus *int` with:

```go
Status string `form:"status" binding:"omitempty,oneof=running success failed canceled timeout"`
```

In `ListQuery`, use `Status string`.

- [ ] **Step 3: Update repository selects and joins**

Use new columns:

```sql
r.status, r.model_id, r.model_display_name,
r.prompt_tokens, r.completion_tokens, r.total_tokens,
r.duration_ms, r.error_message, r.created_at
```

Events select:

```sql
id, seq, event_type, message, created_at
```

Stats SQL:

```go
func statsSummarySelectSQL() string {
	return "COUNT(*) as total_runs, SUM(CASE WHEN r.status = ? THEN 1 ELSE 0 END) as success_runs, SUM(CASE WHEN r.status IN (?, ?, ?) THEN 1 ELSE 0 END) as fail_runs, COALESCE(SUM(r.total_tokens), 0) as total_tokens, COALESCE(SUM(r.prompt_tokens), 0) as prompt_tokens, COALESCE(SUM(r.completion_tokens), 0) as completion_tokens, COALESCE(CAST(ROUND(AVG(r.duration_ms)) AS SIGNED), 0) as avg_duration_ms"
}
```

Call with:

```go
enum.AIRunStatusSuccess, enum.AIRunStatusFailed, enum.AIRunStatusCanceled, enum.AIRunStatusTimeout
```

- [ ] **Step 4: Update mapping helpers**

Replace `latencyString` with:

```go
func durationText(value *uint) string {
	if value == nil {
		return "-"
	}
	if *value < 1000 {
		return fmt.Sprintf("%dms", *value)
	}
	return fmt.Sprintf("%.2fs", float64(*value)/1000)
}
```

Use `enum.AIRunStatusLabels[row.Status]`.

- [ ] **Step 5: Update tests**

Change tests to assert:

```go
status := enum.AIRunStatusSuccess
repo := &fakeRepository{rows: []ListRow{{ID: 1, RequestID: "rid", UserID: 7, AgentID: 3, AgentName: "agent", ProviderID: 2, ProviderName: "OpenAI", ConversationID: 4, ConversationTitle: "chat", Status: status, ModelID: "gpt-5.4", ModelDisplayName: "GPT-5.4", TotalTokens: 12, DurationMS: ptrUint(1530), CreatedAt: created}}, total: 1}
res, appErr := NewService(repo).List(context.Background(), ListQuery{Status: status, RequestID: " rid ", AgentID: &agentID, CurrentPage: 0, PageSize: 0})
if len(res.List) != 1 || res.List[0].DurationText != "1.53s" || res.List[0].StatusName != "成功" {
	t.Fatalf("unexpected list response: %#v", res)
}
```

Event test should expect `event_type=start/completed` and `message`, not payload/delta.

- [ ] **Step 6: Run tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/airun -count=1
```

Expected: pass.

---

## Task 4: Frontend run monitor contract update

**Files:**
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/runs/components/RunStats/index.vue`
- Test: `admin_front_ts/tests/shared/ai/ai-runs-api.test.ts`

- [ ] **Step 1: Update API types**

In `runs.ts`, set:

```ts
status_arr: DictOption<string>[]
status?: 'running' | 'success' | 'failed' | 'canceled' | 'timeout' | ''
```

Replace item fields:

```ts
status: string
status_name: string
model_id: string
model_display_name: string
prompt_tokens: number
completion_tokens: number
total_tokens: number
duration_ms?: number | null
duration_text: string
error_message: string
```

Event fields:

```ts
seq: number
event_type: string
message: string
created_at: string
```

- [ ] **Step 2: Update query normalizer**

Replace:

```ts
if (typeof params.run_status === 'number') query.run_status = params.run_status
```

with:

```ts
if (params.status) query.status = params.status
```

Do not keep `run_status` alias.

- [ ] **Step 3: Update RunList page**

Replace `searchForm.run_status` with `searchForm.status`.

Replace columns:

```ts
{key: 'status', label: t('aiRuns.table.status'), width: 100},
{key: 'model_display_name', label: t('aiRuns.table.model'), width: 160},
{key: 'total_tokens', label: t('aiRuns.table.tokens'), width: 100},
{key: 'duration_text', label: t('aiRuns.table.latency'), width: 100},
{key: 'error_message', label: t('aiRuns.table.error'), width: 220, overflowTooltip: true},
```

Status tag helper:

```ts
const getStatusType = (status: string) => {
  switch (status) {
    case 'running': return 'warning'
    case 'success': return 'success'
    case 'failed': return 'danger'
    case 'canceled': return 'info'
    case 'timeout': return 'danger'
    default: return 'info'
  }
}
```

- [ ] **Step 4: Remove step UI**

Delete `AiRunStepItem`, `getStepTokenPayload`, and the execution steps timeline from `RunList/index.vue`. It is not part of this MVP.

- [ ] **Step 5: Update stats labels only if needed**

Keep token cards. Replace latency display source with `avg_duration_ms` if backend DTO changed from `avg_latency_ms` to `avg_duration_ms`; otherwise keep `avg_latency_ms` temporarily only if backend contract deliberately keeps response name. Pick one name and make API + component match.

- [ ] **Step 6: Run frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
```

Expected: no type errors.

---

## Task 5: Docs and verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/migration/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update API contract**

Change AI Runs Monitor section to:

```text
状态：implemented for token-only run monitor.
Tables: ai_runs, ai_run_events.
No daily aggregate table, no billing amount, no provider task id.
Status: running/success/failed/canceled/timeout.
Events: start/completed/failed/canceled/timeout.
```

- [ ] **Step 2: Update smoke matrix**

Change AI conversation/runs gate to assert:

```text
GET /api/admin/v1/ai-runs/page-init returns string status options.
GET /api/admin/v1/ai-runs returns status/model_id/model_display_name/token/duration fields and no removed aliases.
GET /api/admin/v1/ai-runs/stats returns token-only aggregates.
```

- [ ] **Step 3: Run backend tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai/openaicompat ./internal/module/aimessage ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
```

Expected: pass.

- [ ] **Step 4: Verify live DB shape**

```sql
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('ai_runs','ai_run_events','ai_usage_daily')
ORDER BY TABLE_NAME;
```

Expected:

```text
ai_run_events
ai_runs
```

Run column scan:

```sql
SELECT COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'ai_runs'
ORDER BY ORDINAL_POSITION;
```

Expected no:

```text
billing amount
raw usage dump
input_snapshot_json
output_snapshot_json
engine_task_id
engine_run_id
model_snapshot
run_status
latency_ms
error_msg
```

- [ ] **Step 5: Residue scan**

```powershell
rg -n "usage_json|input_snapshot_json|output_snapshot_json|engine_task_id|engine_run_id|model_snapshot|run_status|latency_ms|error_msg" admin_back_go/internal/module/aichat admin_back_go/internal/module/airun admin_front_ts/src/api/ai/runs.ts admin_front_ts/src/views/Main/ai/runs docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md docs/migration/current-status.md
```

Expected: no active run monitor contract residue.

---

## Current Execution Choice

The user already approved the schema and asked to proceed. Execute inline in this session to keep DB/code/docs consistent with the live migration that has already been applied.
