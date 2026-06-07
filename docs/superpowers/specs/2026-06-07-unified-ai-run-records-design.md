# Unified AI Run Records Design

Status: proposed design for implementation
Date: 2026-06-07
Project role: api-contract
Task class: code bug

## Requirement analysis

【需求判断】
是真问题。当前 Admin 的“AI 运行记录”只可靠覆盖 Admin 对话回复链路；Canvas 文生文、Canvas 生图、Canvas 视频、Admin 生图都可能真实调用 provider，但不会统一写入 `ai_runs`。

【核心问题】
真正的问题不是前端少调接口，而是后端把“AI 运行记录”设计成了 chat-only 数据结构。`ai_runs` 当前强绑定 `ai_conversations` / `ai_messages`，而生图和视频走 `ai_image_tasks` / `canvas_video_tasks`，Canvas 文生文甚至是无持久任务的同步调用。

【复杂度检查】
不能通过给图片和视频伪造 conversation/message 来凑 `ai_runs` 外键。这会污染对话数据，后面所有统计和详情都会变成假账。正确做法是让 `ai_runs` 成为统一 AI provider attempt 记录，再让 chat/image/video 通过明确 source 字段关联自己的业务对象。

【破坏性分析】
现有 Admin chat 运行记录、统计、详情必须继续可读；Canvas free-generation 仍然免费，不恢复 `ai_billing_records`、不查余额、不扣钱包。Admin `/api/admin/v1/ai-runs*` endpoint 路径不变，只扩展返回字段和筛选项。

## Current evidence

当前证据来自 live schema snapshot 和 Go source：

- `ai_runs` 当前 `conversation_id`、`user_message_id` 非空，并通过外键绑定 `ai_conversations` / `ai_messages`。
- Admin chat 通过 `internal/module/ai/chat` 创建、完成 `ai_runs`。
- Canvas text 使用 `CanvasCompletion` 直接调用 `engine.StreamChat`，没有创建 run。
- Admin/Canvas image 只创建 `ai_image_tasks`，worker 调 provider 后只更新 image task。
- Canvas video 只创建 `canvas_video_tasks`，调用 provider 后只更新 video task。
- `infra/ai.ImageResult` 当前没有 image usage 字段；即使 provider 返回 image `usage`，也没有结构保存。

## Design alternatives

### Option A: Make `ai_runs` a unified provider-attempt table, selected

Add generic source fields to `ai_runs`, relax chat-only nullable columns, and introduce a small recorder owned by `internal/module/ai/run`. Chat, Canvas text, image worker, and video service all write through it.

Pros:

- One table powers the existing Admin AI run monitor.
- Old chat rows continue to work.
- No fake conversation/message records.
- Image/video can keep their own task tables.

Cons:

- Requires one migration and small API/frontend DTO expansion.
- Requires moving write ownership out of `ai/chat` over a staged implementation.

### Option B: Add separate run tables per modality, rejected

Create `ai_image_runs`, `ai_video_runs`, and maybe `canvas_text_runs`.

Pros:

- Avoids changing current `ai_runs` schema.

Cons:

- Duplicates status, token, duration, provider, model, event logic.
- Admin monitor must join multiple tables or show separate pages.
- This is exactly the special-case explosion this project should not accept.

### Option C: Store image/video as fake chat conversations, rejected

Create hidden conversations and messages for every image/video request.

Pros:

- Minimal schema change.

Cons:

- Corrupts chat domain with non-chat data.
- Breaks user expectations in conversation history.
- Makes run details lie about messages.

## Selected design

Use Option A. `ai_runs` becomes the canonical AI provider-attempt audit table. Domain task tables stay as domain task tables:

```text
Admin chat message        -> ai_runs(source_type='ai_chat_message', source_id=ai_messages.id, modality='chat')
Canvas text completion    -> ai_text_tasks row -> ai_runs(source_type='ai_text_task', source_id=ai_text_tasks.id, modality='text')
Admin/Canvas image task   -> ai_image_tasks row -> ai_runs(source_type='ai_image_task', source_id=ai_image_tasks.id, modality='image')
Canvas video task         -> canvas_video_tasks row -> ai_runs(source_type='canvas_video_task', source_id=canvas_video_tasks.id, modality='video')
```

## Data model contract

`ai_runs` keeps existing columns and gains only fields with a required producer and consumer:

```sql
platform              VARCHAR(32)  NOT NULL
modality              VARCHAR(32)  NOT NULL
source_type           VARCHAR(64)  NOT NULL
source_id             BIGINT UNSIGNED NOT NULL
input_snapshot        MEDIUMTEXT    NOT NULL
usage_status          VARCHAR(16)   NOT NULL
```

Existing chat-only fields change to nullable:

```sql
conversation_id       INT UNSIGNED NULL
user_message_id       BIGINT UNSIGNED NULL
assistant_message_id  BIGINT UNSIGNED NULL
```

These nullable chat-only fields are not fallbacks. They are valid only when `modality='chat'`; non-chat rows are identified by `source_type/source_id/input_snapshot`.

Existing old rows are backfilled as:

```text
platform='admin'
modality='chat'
source_type='ai_chat_message'
source_id=user_message_id
input_snapshot=ai_messages.content
usage_status='reported' when existing stored token fields prove provider usage was recorded; otherwise 'unavailable' because old rows have no separate usage-evidence field
```

Indexes:

```sql
idx_ai_runs_platform_modality_created(platform, modality, created_at, id)
idx_ai_runs_source(source_type, source_id, created_at, id)
```

Uniqueness:

```sql
uk_ai_runs_source_request(source_type, source_id, request_id)
```

`source_id` is never nullable. Canvas text gets a real source row in `ai_text_tasks`; no row uses a generated request id as a fake source.

New `ai_text_tasks` fields:

```sql
id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
platform        VARCHAR(32) NOT NULL
user_id         BIGINT UNSIGNED NOT NULL
agent_id        BIGINT UNSIGNED NOT NULL
provider_id     BIGINT UNSIGNED NOT NULL
model_id        VARCHAR(191) NOT NULL
prompt          MEDIUMTEXT NOT NULL
answer          MEDIUMTEXT NULL
status          VARCHAR(16) NOT NULL
error_message   VARCHAR(1024) NULL
started_at      DATETIME NULL
finished_at     DATETIME NULL
elapsed_ms      INT UNSIGNED NOT NULL
created_at      DATETIME NOT NULL
updated_at      DATETIME NOT NULL
```

Every field has a producer and consumer: the Canvas text service writes it, the run recorder links through it, and Admin run detail can show the source prompt/status without inventing chat messages.

## No fallback field rule

This slice must not add fields “just in case”.

- No new column uses a permanent default to hide a missing caller value. Migration may add nullable columns, backfill from existing data, then modify to `NOT NULL`.
- `platform`, `modality`, `source_type`, `source_id`, `input_snapshot`, and `usage_status` must be written by a named producer; missing values must fail before the provider call.
- `source_id` must point to a real source row for every run.
- `cost` is not added because current provider clients do not produce source-backed cost.
- `usage_json` is not added because current Admin UI and stats do not consume raw provider usage. Provider usage is normalized into existing token fields plus `usage_status`.
- `usage_status` has exactly three valid states:
  - `pending`: the run has started and provider usage is not known yet.
  - `reported`: a terminal provider result included usage and token fields were persisted from that provider result.
  - `unavailable`: a terminal provider result or failure path did not include provider usage.
- Token totals are never guessed from prompt length, image count, duration, or model name.

`ai_run_events` remains lifecycle-only:

```text
start / completed / failed / canceled / timeout
```

No delta stream, image bytes, provider secrets, or request body dumps go into `ai_run_events`.

## Backend recorder contract

Create a recorder in `internal/module/ai/run` with one responsibility: start and finish provider attempts.

```go
type Recorder interface {
    Start(ctx context.Context, input StartInput) (uint64, error)
    Complete(ctx context.Context, input CompleteInput) error
    Fail(ctx context.Context, input FailInput) error
    Timeout(ctx context.Context, input TimeoutInput) error
}
```

Rules:

- Start before the first provider call.
- If Start fails, do not call provider. This is fail-closed audit behavior.
- Start writes `usage_status='pending'`; terminal paths must change it to `reported` or `unavailable`.
- Complete/Fail writes one terminal event exactly once.
- Terminal updates use compare-and-set from `running` to avoid duplicate worker retries corrupting rows.
- `request_id` is caller-provided for Admin chat, otherwise generated server-side as a stable non-empty value.

## Modality behavior

### Admin chat

Preserve behavior and fields. Chat continues to link `conversation_id`, `user_message_id`, `assistant_message_id`, token totals, duration, and events. The write path moves to the recorder so future modalities do not duplicate `ai_runs` write logic.

### Canvas text completion

`POST /api/canvas/v1/ai/chat/completions` starts a run with:

```text
platform=canvas
modality=text
source_type=ai_text_task
source_id=ai_text_tasks.id
input_snapshot=ai_text_tasks.prompt
```

It creates `ai_text_tasks` before the provider call, completes that row with the answer/status, and completes the run with provider token totals. The API response shape remains unchanged.

### Admin and Canvas image generation

Image task creation stays in `ai_image_tasks`. The run starts in the worker after the task is claimed and before `GenerateImages` is called:

```text
platform=admin or canvas
modality=image
source_type=ai_image_task
source_id=ai_image_tasks.id
input_snapshot=ai_image_tasks.prompt
```

The worker completes or fails both the image task and its run in one DB transaction. Provider image usage is parsed into `ImageResult` and saved to existing `ai_runs.prompt_tokens/completion_tokens/total_tokens` when present, with `usage_status='reported'`. Missing provider usage sets `usage_status='unavailable'`; token values are not guessed.

To preserve platform, `ai_image_tasks` gains:

```sql
platform VARCHAR(32) NOT NULL
```

The service must set `platform` explicitly: Admin transport writes `admin`, Canvas transport writes `canvas`.

Existing rows backfill to `admin`; Canvas transport writes `canvas`.

### Canvas video generation

Video task creation stays in `canvas_video_tasks`. Start a run before `CreateVideo`:

```text
platform=canvas
modality=video
source_type=canvas_video_task
source_id=canvas_video_tasks.id
input_snapshot=canvas_video_tasks.prompt
```

If provider returns a running provider task, the run remains `running`. When `GET /api/canvas/v1/ai/videos/:id` observes a terminal provider status, update the video task and the run in one DB transaction:

```text
completed -> ai_runs.status=success
failed/cancelled -> ai_runs.status=failed or canceled
```

If the user never polls and the row stays running, the existing AI run timeout worker marks stale rows as timeout.

## Admin API contract

Existing routes remain:

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

New optional filters:

```text
platform=admin|canvas|app|openapi|merchant|miniapp
modality=chat|text|image|video
source_type=ai_chat_message|ai_text_task|ai_image_task|canvas_video_task
```

List item adds:

```ts
interface AiRunItem {
  platform: string
  modality: 'chat' | 'text' | 'image' | 'video'
  source_type: string
  source_id: number
  input_snapshot: string
  usage_status: 'pending' | 'reported' | 'unavailable'
}
```

Detail adds the same fields plus:

```ts
interface AiRunDetailResponse {
  input_snapshot: string
  usage_status: 'pending' | 'reported' | 'unavailable'
  user_message: AiRunMessageSummary | null
  assistant_message: AiRunMessageSummary | null
}
```

For non-chat rows, `user_message` and `assistant_message` are `null` by design. Frontend must render the source/prompt summary instead of inventing message content.

Stats endpoints include all modalities by default. Existing consumers that do not pass the new filters still see chat rows plus the newly recorded non-chat rows.

## Error handling

- Recorder unavailable before provider call: return internal error and do not call provider.
- Image worker recorder failure: mark image task failed with a clear message and skip provider call.
- Image/video terminal transaction failure after provider response: return worker/service error; transaction keeps task/run state consistent.
- Provider usage missing: set `usage_status='unavailable'`; do not guess token counts from prompt length, image count, video duration, or model name.
- Provider secrets never enter `input_snapshot`, operation log, or run event messages.

## Frontend impact

Admin Vue AI run page keeps the same route and API wrapper. It adds filters and columns for platform/modality/source. Detail dialog shows:

```text
chat rows: existing messages, tool calls, knowledge retrievals
text/image/video rows: input snapshot, source id, provider/model/status/tokens/usage status/events
```

Canvas Next does not call any new API for run recording. Its generation calls remain unchanged.

## Testing strategy

Backend tests must cover:

- Migration shape through schema drift guard or migration unit test.
- `airun.Recorder` start/complete/fail idempotency and event sequencing.
- Admin chat still creates the same run fields.
- Canvas text completion creates and completes a text run.
- Image worker creates and completes/fails an image run; no provider call happens if run start fails.
- Image response `usage` is parsed and persisted.
- Canvas video creates a video run and terminal status updates finish it.
- Admin run list/detail supports non-chat rows without requiring message joins.

Frontend tests must cover:

- `AiRunApi` query normalization for platform/modality/source filters.
- Run list/detail rendering does not require chat messages for image/video rows.
- i18n keys exist for new labels.

## Acceptance criteria

- A successful Admin image generation creates one `ai_runs` row with `platform=admin`, `modality=image`, `source_type=ai_image_task`, `source_id=<ai_image_tasks.id>`.
- A successful Canvas image generation creates one `ai_runs` row with `platform=canvas`, `modality=image`.
- A successful Canvas text completion creates one `ai_runs` row with `platform=canvas`, `modality=text`.
- A Canvas video request creates one `ai_runs` row with `platform=canvas`, `modality=video`, and terminal polling finishes it.
- Admin chat run monitor still displays old and new chat rows.
- Admin run monitor shows image/text/video rows without fake conversations.
- `ai_billing_records` remains retired for Canvas free generation.
- No provider API key, base URL secret, raw image bytes, or captcha data is persisted into run records.
