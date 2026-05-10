# AI Stream Timeout Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the brittle 30-second AI streaming HTTP total timeout with layered stream timeout governance and stale-run cleanup.

**Architecture:** `admin-api` owns the live chat reply execution and uses context max duration plus provider stream idle timeout. `admin-worker` keeps `ai_run_timeout` as a DB stale-run sweeper only. Existing `ai_runs` and `ai_run_events` remain the runtime truth; no schema expansion is introduced.

**Tech Stack:** Go + Gin + GORM + MySQL 8 + existing gocron/asynq worker + existing WebSocket realtime envelope.

---

## Scope Lock

Implement only:

```text
AI stream timeout governance
OpenAI-compatible stream usage collection
stale running run sweep safety
docs/tests for the above
```

Do not implement:

```text
new tables
new ai_runs columns
new frontend UI
partial assistant persistence
Responses API migration
OpenAI direct WebSocket adapter
provider retry engine
```

---

## File Structure

### Backend

```text
admin_back_go/internal/config/config.go
  - add AIConfig with ChatStreamMaxDuration, ChatStreamIdleTimeout, RunStaleTimeout

admin_back_go/internal/config/config_test.go
  - verify AI timeout defaults and env overrides

admin_back_go/internal/bootstrap/app.go
  - pass AI timeout config into chat engine factory and reply dispatcher

admin_back_go/internal/bootstrap/worker.go
  - pass RunStaleTimeout into aichat service used by worker jobs

admin_back_go/internal/bootstrap/ai_reply_dispatcher.go
  - keep dispatcher behavior; consume configured timeout instead of hard-coded timeout at call site

admin_back_go/internal/bootstrap/ai_reply_dispatcher_test.go
  - verify timeout config is applied and cancellation behavior is preserved

admin_back_go/internal/platform/ai/openaicompat/client.go
  - split normal HTTP timeout from streaming HTTP client
  - add stream idle timeout
  - add stream_options.include_usage=true

admin_back_go/internal/platform/ai/openaicompat/client_test.go
  - prove stream is not killed by total HTTP timeout
  - prove idle stream times out
  - prove stream_options.include_usage is sent

admin_back_go/internal/module/aichat/dto.go
  - extend RunTimeoutInput and repository TimeoutRuns signature with stale cutoff

admin_back_go/internal/module/aichat/service.go
  - add RunStaleTimeout dependency, default it, and apply it in TimeoutRuns

admin_back_go/internal/module/aichat/repository.go
  - only sweep stale running rows
  - only append terminal event when terminal update actually changes a running row

admin_back_go/internal/module/aichat/service_test.go
  - verify TimeoutRuns passes stale age and status mapping still works

admin_back_go/internal/module/aichat/repository_test.go
  - verify stale-only sweep and no duplicate terminal event on already terminal run
```

### Docs

```text
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Add AI timeout config

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add config struct**

In `admin_back_go/internal/config/config.go`, add an `AI` field to `Config`:

```go
type Config struct {
	App         AppConfig
	HTTP        HTTPConfig
	Logging     LoggingConfig
	MySQL       MySQLConfig
	Redis       RedisConfig
	Token       TokenConfig
	Captcha     CaptchaConfig
	VerifyCode  VerifyCodeConfig
	Queue       QueueConfig
	Realtime    RealtimeConfig
	Scheduler   SchedulerConfig
	Secretbox   SecretboxConfig
	Payment     PaymentConfig
	UploadToken UploadTokenConfig
	AI          AIConfig
	CORS        CORSConfig
}

type AIConfig struct {
	ChatStreamMaxDuration time.Duration
	ChatStreamIdleTimeout time.Duration
	RunStaleTimeout       time.Duration
}
```

- [ ] **Step 2: Load defaults and env overrides**

In `Load()`, add this block before `CORS: corsConfig`:

```go
AI: AIConfig{
	ChatStreamMaxDuration: envDuration("AI_CHAT_STREAM_MAX_DURATION", 5*time.Minute),
	ChatStreamIdleTimeout: envDuration("AI_CHAT_STREAM_IDLE_TIMEOUT", 60*time.Second),
	RunStaleTimeout:       envDuration("AI_RUN_STALE_TIMEOUT", 15*time.Minute),
},
```

- [ ] **Step 3: Add config tests**

In `admin_back_go/internal/config/config_test.go`, add:

```go
func TestLoadAIConfigDefaults(t *testing.T) {
	cfg := Load()
	if cfg.AI.ChatStreamMaxDuration != 5*time.Minute {
		t.Fatalf("expected AI chat stream max duration 5m, got %s", cfg.AI.ChatStreamMaxDuration)
	}
	if cfg.AI.ChatStreamIdleTimeout != 60*time.Second {
		t.Fatalf("expected AI chat stream idle timeout 60s, got %s", cfg.AI.ChatStreamIdleTimeout)
	}
	if cfg.AI.RunStaleTimeout != 15*time.Minute {
		t.Fatalf("expected AI run stale timeout 15m, got %s", cfg.AI.RunStaleTimeout)
	}
}

func TestLoadAIConfigFromEnv(t *testing.T) {
	t.Setenv("AI_CHAT_STREAM_MAX_DURATION", "3m")
	t.Setenv("AI_CHAT_STREAM_IDLE_TIMEOUT", "45s")
	t.Setenv("AI_RUN_STALE_TIMEOUT", "20m")

	cfg := Load()
	if cfg.AI.ChatStreamMaxDuration != 3*time.Minute {
		t.Fatalf("expected AI chat stream max duration 3m, got %s", cfg.AI.ChatStreamMaxDuration)
	}
	if cfg.AI.ChatStreamIdleTimeout != 45*time.Second {
		t.Fatalf("expected AI chat stream idle timeout 45s, got %s", cfg.AI.ChatStreamIdleTimeout)
	}
	if cfg.AI.RunStaleTimeout != 20*time.Minute {
		t.Fatalf("expected AI run stale timeout 20m, got %s", cfg.AI.RunStaleTimeout)
	}
}
```

- [ ] **Step 4: Run config tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/config
```

---

## Task 2: Wire config into API and worker runtime

**Files:**
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/ai_openai_test.go`
- Modify: `admin_back_go/internal/bootstrap/ai_reply_dispatcher_test.go`

- [ ] **Step 1: Add timeout helpers**

In `admin_back_go/internal/bootstrap/app.go`, add helpers near the AI factory definitions:

```go
func aiReplyTimeout(maxDuration time.Duration) time.Duration {
	if maxDuration <= 0 {
		maxDuration = 5 * time.Minute
	}
	return maxDuration + 30*time.Second
}

func positiveDuration(value time.Duration, fallback time.Duration) time.Duration {
	if value <= 0 {
		return fallback
	}
	return value
}
```

- [ ] **Step 2: Pass dispatcher timeout**

Replace:

```go
aiReplyDispatcher := newAIConversationReplyDispatcher(aiChatService, logger, aiConversationReplyTimeout)
```

with:

```go
aiReplyDispatcher := newAIConversationReplyDispatcher(aiChatService, logger, aiReplyTimeout(cfg.AI.ChatStreamMaxDuration))
```

- [ ] **Step 3: Give `aichat.Service` stale timeout**

In API bootstrap service creation, add:

```go
RunStaleTimeout: positiveDuration(cfg.AI.RunStaleTimeout, 15*time.Minute),
```

to `aichat.Dependencies`.

In worker bootstrap service creation, add the same field:

```go
RunStaleTimeout: positiveDuration(cfg.AI.RunStaleTimeout, 15*time.Minute),
```

- [ ] **Step 4: Make chat engine factory configurable**

Change:

```go
type aiChatEngineFactory struct{}
```

to:

```go
type aiChatEngineFactory struct {
	streamIdleTimeout time.Duration
}
```

Use it in API bootstrap:

```go
EngineFactory: aiChatEngineFactory{streamIdleTimeout: positiveDuration(cfg.AI.ChatStreamIdleTimeout, 60*time.Second)},
```

Keep worker factory as:

```go
EngineFactory: aiChatEngineFactory{streamIdleTimeout: positiveDuration(cfg.AI.ChatStreamIdleTimeout, 60*time.Second)},
```

If `worker.go` cannot access `cfg.AI` in the existing scope, pass the field from the already-loaded `cfg` used by `NewWorker`.

- [ ] **Step 5: Pass idle timeout into OpenAI-compatible client**

In `aiChatEngineFactory.NewEngine`, replace the OpenAI branch config with:

```go
return openaicompat.New(openaicompat.Config{
	BaseURL:           input.BaseURL,
	APIKey:            input.APIKey,
	Timeout:           30 * time.Second,
	StreamIdleTimeout: positiveDuration(e.streamIdleTimeout, 60*time.Second),
}), nil
```

Leave Dify timeout unchanged in this pass.

- [ ] **Step 6: Run bootstrap tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/bootstrap
```

---

## Task 3: Fix OpenAI-compatible stream timeout behavior

**Files:**
- Modify: `admin_back_go/internal/platform/ai/openaicompat/client.go`
- Modify: `admin_back_go/internal/platform/ai/openaicompat/client_test.go`

- [ ] **Step 1: Extend Config and Client**

In `client.go`, extend config and client:

```go
const (
	defaultBaseURL            = "https://api.openai.com/v1"
	defaultTimeout            = 30 * time.Second
	defaultStreamIdleTimeout  = 60 * time.Second
)

type Config struct {
	BaseURL           string
	APIKey            string
	HTTPClient        *http.Client
	StreamHTTPClient  *http.Client
	Timeout           time.Duration
	StreamIdleTimeout time.Duration
}

type Client struct {
	baseURL           string
	apiKey            string
	httpClient        *http.Client
	streamHTTPClient  *http.Client
	timeout           time.Duration
	streamIdleTimeout time.Duration
}
```

- [ ] **Step 2: Build separate clients in `New`**

Use this construction:

```go
timeout := config.Timeout
if timeout <= 0 {
	timeout = defaultTimeout
}
streamIdleTimeout := config.StreamIdleTimeout
if streamIdleTimeout <= 0 {
	streamIdleTimeout = defaultStreamIdleTimeout
}
httpClient := config.HTTPClient
if httpClient == nil {
	httpClient = &http.Client{Timeout: timeout}
}
streamHTTPClient := config.StreamHTTPClient
if streamHTTPClient == nil {
	streamHTTPClient = &http.Client{}
}
return &Client{
	baseURL:           strings.TrimRight(strings.TrimSpace(config.BaseURL), "/"),
	apiKey:            strings.TrimSpace(config.APIKey),
	httpClient:        httpClient,
	streamHTTPClient:  streamHTTPClient,
	timeout:           timeout,
	streamIdleTimeout: streamIdleTimeout,
}
```

- [ ] **Step 3: Add stream options to request body**

Extend request struct:

```go
type chatCompletionRequest struct {
	Model         string                `json:"model"`
	Messages      []chatMessage         `json:"messages"`
	Stream        bool                  `json:"stream"`
	StreamOptions *chatStreamOptions     `json:"stream_options,omitempty"`
	Tools         []chatTool            `json:"tools,omitempty"`
	Temperature   *float64              `json:"temperature,omitempty"`
	MaxTokens     *int                  `json:"max_tokens,omitempty"`
}

type chatStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}
```

Set it in `StreamChat`:

```go
body := chatCompletionRequest{
	Model:         model,
	Stream:        true,
	StreamOptions: &chatStreamOptions{IncludeUsage: true},
	Messages:      chatMessages(input),
	Tools:         chatTools(input.Tools),
}
```

- [ ] **Step 4: Use streaming client for `StreamChat`**

Replace:

```go
resp, err := c.httpClient.Do(req)
```

with:

```go
streamClient := c.streamHTTPClient
if streamClient == nil {
	streamClient = &http.Client{}
	c.streamHTTPClient = streamClient
}
resp, err := streamClient.Do(req)
```

- [ ] **Step 5: Add idle timer around response body**

Add helper:

```go
type streamIdleWatcher struct {
	timer    *time.Timer
	stop    chan struct{}
	timedOut atomic.Bool
	closeBody func() error
}

func newStreamIdleWatcher(timeout time.Duration, closeBody func() error) *streamIdleWatcher {
	if timeout <= 0 {
		timeout = defaultStreamIdleTimeout
	}
	w := &streamIdleWatcher{
		timer:     time.NewTimer(timeout),
		stop:      make(chan struct{}),
		closeBody: closeBody,
	}
	go func() {
		select {
		case <-w.timer.C:
			w.timedOut.Store(true)
			_ = w.closeBody()
		case <-w.stop:
			if !w.timer.Stop() {
				select {
				case <-w.timer.C:
				default:
				}
			}
		}
	}()
	return w
}

func (w *streamIdleWatcher) Touch(timeout time.Duration) {
	if w == nil {
		return
	}
	if timeout <= 0 {
		timeout = defaultStreamIdleTimeout
	}
	if !w.timer.Stop() {
		select {
		case <-w.timer.C:
		default:
		}
	}
	w.timer.Reset(timeout)
}

func (w *streamIdleWatcher) Stop() {
	if w == nil {
		return
	}
	close(w.stop)
}

func (w *streamIdleWatcher) TimedOut() bool {
	return w != nil && w.timedOut.Load()
}
```

Add `sync/atomic` import.

Use it in `StreamChat` after success status:

```go
watcher := newStreamIdleWatcher(c.streamIdleTimeout, resp.Body.Close)
defer watcher.Stop()
result, err := c.readChatCompletionStream(ctx, resp.Body, sink, func() {
	watcher.Touch(c.streamIdleTimeout)
})
if err != nil {
	if watcher.TimedOut() {
		return nil, fmt.Errorf("%w: OpenAI chat completion stream idle timeout after %s", context.DeadlineExceeded, c.streamIdleTimeout)
	}
	return nil, err
}
```

Change `readChatCompletionStream` signature:

```go
func (c *Client) readChatCompletionStream(ctx context.Context, body io.Reader, sink platformai.EventSink, touch func()) (*platformai.ChatResult, error)
```

Call `touch()` immediately after every successful `scanner.Scan()`:

```go
for scanner.Scan() {
	if touch != nil {
		touch()
	}
	...
}
```

- [ ] **Step 6: Add streaming tests**

In `client_test.go`, add three tests:

```go
func TestClientStreamChatDoesNotUseTotalHTTPTimeout(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, _ := w.(http.Flusher)
		fmt.Fprintln(w, `data: {"choices":[{"delta":{"content":"hello"}}]}`)
		flusher.Flush()
		time.Sleep(120 * time.Millisecond)
		fmt.Fprintln(w, `data: {"choices":[{"delta":{"content":" world"},"finish_reason":"stop"}]}`)
		fmt.Fprintln(w, `data: [DONE]`)
		flusher.Flush()
	}))
	defer server.Close()

	client := New(Config{
		BaseURL:           server.URL,
		APIKey:            "sk-test",
		Timeout:           50 * time.Millisecond,
		StreamIdleTimeout: 500 * time.Millisecond,
	})
	result, err := client.StreamChat(context.Background(), platformai.ChatInput{
		Content: "hi",
		Inputs:  map[string]any{"model_id": "gpt-test"},
	}, nil)
	if err != nil {
		t.Fatalf("StreamChat returned error: %v", err)
	}
	if result.Answer != "hello world" {
		t.Fatalf("unexpected answer %q", result.Answer)
	}
}

func TestClientStreamChatReturnsIdleTimeoutWhenStreamIsSilent(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		if flusher, ok := w.(http.Flusher); ok {
			flusher.Flush()
		}
		time.Sleep(200 * time.Millisecond)
	}))
	defer server.Close()

	client := New(Config{
		BaseURL:           server.URL,
		APIKey:            "sk-test",
		Timeout:           time.Second,
		StreamIdleTimeout: 50 * time.Millisecond,
	})
	_, err := client.StreamChat(context.Background(), platformai.ChatInput{
		Content: "hi",
		Inputs:  map[string]any{"model_id": "gpt-test"},
	}, nil)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline exceeded, got %v", err)
	}
}

func TestClientStreamChatRequestsStreamingUsage(t *testing.T) {
	var body map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.Header().Set("Content-Type", "text/event-stream")
		fmt.Fprintln(w, `data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":4,"total_tokens":7}}`)
		fmt.Fprintln(w, `data: [DONE]`)
	}))
	defer server.Close()

	result, err := New(Config{BaseURL: server.URL, APIKey: "sk-test", StreamIdleTimeout: time.Second}).StreamChat(context.Background(), platformai.ChatInput{
		Content: "hi",
		Inputs:  map[string]any{"model_id": "gpt-test"},
	}, nil)
	if err != nil {
		t.Fatalf("StreamChat returned error: %v", err)
	}
	streamOptions, ok := body["stream_options"].(map[string]any)
	if !ok || streamOptions["include_usage"] != true {
		t.Fatalf("expected stream_options.include_usage=true, got %#v", body["stream_options"])
	}
	if result.TotalTokens != 7 {
		t.Fatalf("expected total tokens 7, got %d", result.TotalTokens)
	}
}
```

Add imports used by the tests: `errors`, `fmt`, and `time` if they are not already present.

- [ ] **Step 7: Run OpenAI-compatible tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/ai/openaicompat
```

Expected:

```text
ok  	admin_back_go/internal/platform/ai/openaicompat
```

---

## Task 4: Make run timeout sweeper stale-only

**Files:**
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/repository.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`
- Modify: `admin_back_go/internal/module/aichat/repository_test.go`

- [ ] **Step 1: Extend service dependencies and timeout input**

In `service.go`, add stale timeout to dependencies without removing the existing `Now` hook:

```go
type Dependencies struct {
	Repository       Repository
	Publisher        platformrealtime.Publisher
	EngineFactory    EngineFactory
	Secretbox        secretbox.Box
	ToolRuntime      ToolRuntime
	KnowledgeRuntime KnowledgeRuntime
	RunStaleTimeout  time.Duration
	Now              func() time.Time
}
```

In `dto.go`, extend `RunTimeoutInput`:

```go
type RunTimeoutInput struct {
	Limit        int
	StaleTimeout time.Duration
}
```

`dto.go` already imports `time`; keep that import.

Change repository interface:

```go
TimeoutRuns(ctx context.Context, limit int, staleBefore time.Time, message string) (int64, error)
```

- [ ] **Step 2: Store stale timeout on service**

In `service.go`, add:

```go
const defaultRunStaleTimeout = 15 * time.Minute
```

Add field to `Service`:

```go
runStaleTimeout time.Duration
```

In `NewService`, set:

```go
runStaleTimeout := deps.RunStaleTimeout
if runStaleTimeout <= 0 {
	runStaleTimeout = defaultRunStaleTimeout
}
service.runStaleTimeout = runStaleTimeout
```

Keep existing dependency initialization unchanged.

- [ ] **Step 3: Compute stale cutoff in service**

Replace `TimeoutRuns` body count call:

```go
count, err := repo.TimeoutRuns(ctx, limit, "AI运行超时")
```

with:

```go
staleTimeout := input.StaleTimeout
if staleTimeout <= 0 {
	staleTimeout = s.runStaleTimeout
}
if staleTimeout <= 0 {
	staleTimeout = defaultRunStaleTimeout
}
staleBefore := s.now().Add(-staleTimeout)
count, err := repo.TimeoutRuns(ctx, limit, staleBefore, "AI运行残留超时")
```

If `Service` does not already expose `now()`, use the existing time helper in this module; otherwise add a `now func() time.Time` field consistent with existing tests.

- [ ] **Step 4: Filter stale rows in repository**

Replace the current query:

```go
Where("status = ?", enum.AIRunStatusRunning)
```

with:

```go
Where("status = ? AND started_at IS NOT NULL AND started_at < ?", enum.AIRunStatusRunning, staleBefore)
```

If `staleBefore.IsZero()`, use:

```go
staleBefore = time.Now().Add(-defaultRunStaleTimeout)
```

- [ ] **Step 5: Avoid duplicate terminal events**

In `finishRun`, capture update result:

```go
result := tx.Model(&Run{}).Where("id = ? AND status = ?", runID, enum.AIRunStatusRunning).Updates(updates)
if result.Error != nil {
	return result.Error
}
if result.RowsAffected == 0 {
	return nil
}
```

Only after `RowsAffected == 1` calculate `maxSeq` and insert `RunEvent`.

- [ ] **Step 6: Add service unit test for stale timeout**

In `service_test.go`, extend `fakeRepository.TimeoutRuns` to capture `staleBefore`.

Add:

```go
func TestTimeoutRunsUsesConfiguredStaleTimeout(t *testing.T) {
	repo := &fakeRepository{}
	now := time.Date(2026, 5, 10, 12, 0, 0, 0, time.UTC)
	service := NewService(Dependencies{Repository: repo, RunStaleTimeout: 20 * time.Minute})
	service.now = func() time.Time { return now }

	res, err := service.TimeoutRuns(context.Background(), RunTimeoutInput{Limit: 5})
	if err != nil {
		t.Fatalf("TimeoutRuns returned error: %v", err)
	}
	if res.Failed != repo.timeoutCount {
		t.Fatalf("expected failed count %d, got %d", repo.timeoutCount, res.Failed)
	}
	want := now.Add(-20 * time.Minute)
	if !repo.staleBefore.Equal(want) {
		t.Fatalf("expected staleBefore %s, got %s", want, repo.staleBefore)
	}
}
```

Adapt field names to the existing fake repository in the file.

- [ ] **Step 7: Add repository tests**

If `repository_test.go` already exists for `aichat`, add tests there. If it does not exist, create it with the existing repository test DB helper used by nearby modules.

Required cases:

```text
running run started 1 minute ago with stale timeout 15 minutes -> not changed
running run started 20 minutes ago with stale timeout 15 minutes -> status timeout and one timeout event
success run passed to FinishRun(timeout) -> no extra event inserted
```

Use concrete assertions:

```go
if run.Status != enum.AIRunStatusRunning { t.Fatalf(...) }
if run.Status != enum.AIRunStatusTimeout { t.Fatalf(...) }
if count != 1 { t.Fatalf("expected one timeout event, got %d", count) }
```

- [ ] **Step 8: Run aichat tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/aichat
```

Expected:

```text
ok  	admin_back_go/internal/module/aichat
```

---

## Task 5: Update docs and contracts

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/migration/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update AI runtime contract**

In `docs/contracts/admin-api-v1.md`, update the AI conversation / run monitor text to state:

```text
AI chat streaming timeout is layered:
- provider stream request does not use a 30s total HTTP timeout
- live reply max duration is controlled by AI_CHAT_STREAM_MAX_DURATION
- upstream silence is controlled by AI_CHAT_STREAM_IDLE_TIMEOUT
- ai_run_timeout only marks stale running rows older than AI_RUN_STALE_TIMEOUT
```

Do not add new API fields.

- [ ] **Step 2: Update cron task contract**

In the `cron_task.name=ai_run_timeout` section, replace broad timeout wording with:

```text
worker marks only stale running ai_runs as timeout:
status='running' AND started_at < now - AI_RUN_STALE_TIMEOUT
```

- [ ] **Step 3: Update smoke matrix**

In `docs/testing/smoke-matrix.md`, update the AI cron note:

```text
ai_run_timeout is a stale-run sweeper only; smoke checks registry/list shape and does not intentionally kill a fresh running AI reply.
```

- [ ] **Step 4: Update current status**

In `docs/migration/current-status.md`, update AI conversation / run monitor remaining risk:

```text
stream timeout governance is layered; online stream max/idle timeout and stale-run cron cleanup are separate.
```

- [ ] **Step 5: Update backend architecture**

In `admin_back_go/docs/architecture.md`, add `AIConfig` under config/runtime boundaries:

```text
internal/config AI timeout config: stream max duration, stream idle timeout, run stale timeout
```

- [ ] **Step 6: Run contract check**

Run:

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected:

```text
contract check passed
```

---

## Task 6: Final verification

**Files:**
- Read-only verification across backend and docs.

- [ ] **Step 1: Run focused backend tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config ./internal/bootstrap ./internal/platform/ai/openaicompat ./internal/module/aichat
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/platform/ai/openaicompat
ok  	admin_back_go/internal/module/aichat
```

- [ ] **Step 2: Run wider backend tests for touched runtime**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/airun ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/module/airun
ok  	admin_back_go/internal/module/crontask
ok  	admin_back_go/internal/jobs
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 3: Run vet**

Run:

```powershell
cd E:/admin_go/admin_back_go
go vet ./...
```

Expected:

```text
no output and exit code 0
```

- [ ] **Step 4: Residue scan for bad 30s stream config**

Run:

```powershell
cd E:/admin_go
rg -n "StreamChat|http\\.Client\\{Timeout: 30 \\* time\\.Second\\}|AI_CHAT_STREAM|AI_RUN_STALE_TIMEOUT|ai_run_timeout" admin_back_go/internal docs
```

Expected:

```text
No StreamChat path uses http.Client{Timeout: 30 * time.Second}.
AI_CHAT_STREAM_MAX_DURATION, AI_CHAT_STREAM_IDLE_TIMEOUT, and AI_RUN_STALE_TIMEOUT appear in config, runtime wiring, tests, and docs.
ai_run_timeout docs describe stale running rows only.
```

- [ ] **Step 5: Optional local runtime smoke**

Only if `admin-api`, `admin-worker`, MySQL, Redis, and a valid provider are running:

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected:

```text
AI conversation/read probes and cron registry probes pass.
```

If provider credentials are not configured, do not claim real provider E2E passed. Report it as credential-gated.

---

## Self-Review Checklist

- No schema expansion: the plan adds no table and no `ai_runs` column.
- Every new config field has a runtime consumer and a test.
- `ai_run_timeout` is explicitly stale-only and cannot kill fresh `running` rows.
- OpenAI-compatible streaming no longer uses a short total HTTP timeout.
- Token usage uses existing fields through `stream_options.include_usage=true`.
- Frontend is untouched because the runtime contract and displayed fields do not change.
