# AI Image Single Capability Convergence Design

## Outcome

Collapse the current Admin/Canvas image split back into one AI image capability.

The current dirty implementation creates two product modules:

```text
internal/module/ai/adminimage
internal/module/canvas/image
```

and four runtime tables:

```text
admin_ai_image_tasks
admin_ai_image_files
canvas_image_tasks
canvas_image_files
```

That is the wrong data structure. Image generation is an AI capability exposed through multiple platform transports. Canvas is an entry point, not the owner of the image-generation runtime.

## Decision

Use one backend capability:

```text
internal/module/ai/image
```

with platform-specific HTTP surfaces:

```text
internal/module/ai/image/transport/admin
internal/module/ai/image/transport/canvas
```

Use one task table and one task-file table:

```text
ai_image_tasks
ai_image_files
```

`ai_image_tasks.platform` separates `admin` and `canvas` entries. That is not a silent fallback; it is the normal platform dimension already used across the project.

## Why the current split is wrong

### 1. Wrong module owner

Canvas chat and Canvas video routes already use AI modules:

```text
internal/module/ai/chat/transport/canvas
internal/module/ai/video/transport/canvas
```

Image should follow the same rule:

```text
internal/module/ai/image/transport/canvas
```

Putting image runtime under `internal/module/canvas/image` makes image the only AI runtime owned by Canvas. That creates a special case for no business gain.

### 2. Duplicate service/repository/model code

The current split duplicates the same runtime concerns:

```text
agent validation
provider snapshot
COS read/write
task queue enqueue
worker execution
output persistence
ai_runs recording
task detail DTO
```

Those are not separate products. They are one image-generation task lifecycle.

### 3. Extra tables solve no real problem

The real distinction is:

```text
platform = admin | canvas
scene    = image_generate | canvas_image_generate
```

That distinction belongs in `ai_image_tasks`, not in four separate tables.

### 4. Canvas browser history is a real bug

Current Canvas image page stores generation logs in browser `localforage`:

```text
infinite-canvas:image_generation_logs
```

This loses records across browsers/devices and duplicates backend task state. Canvas generation history must come from backend `ai_image_tasks`.

## Data model

### `ai_image_tasks`

Purpose: one image-generation job, regardless of platform.

Required columns:

| Column | Purpose |
| --- | --- |
| `id` | task id |
| `platform` | `admin` or `canvas`; required |
| `user_id` | owner user |
| `agent_id` | selected `ai_agents.id` |
| `agent_name_snapshot` | display/debug snapshot |
| `provider_id_snapshot` | run audit |
| `provider_name_snapshot` | run audit |
| `model_id_snapshot` | provider model id |
| `model_display_name_snapshot` | display |
| `prompt` | generation prompt |
| `size` | request size |
| `quality` | request quality |
| `output_format` | admin/client output format |
| `output_compression` | nullable compression |
| `moderation` | request moderation |
| `n` | requested output count |
| `status` | `pending/running/success/failed` |
| `error_message` | failure reason |
| `raw_response_json` | provider debug payload |
| `is_favorite` | admin favorite; Canvas can ignore |
| `is_del` | soft delete |
| `created_at/updated_at/finished_at` | lifecycle |

Indexes:

```text
(platform, user_id, is_del, created_at, id)
(platform, user_id, status, is_del, created_at, id)
(platform, user_id, is_favorite, is_del, created_at, id)
(agent_id, created_at, id)
(status, created_at, id)
```

### `ai_image_files`

Purpose: task-owned input, mask, and output files.

Required columns:

| Column | Purpose |
| --- | --- |
| `id` | file id |
| `task_id` | `ai_image_tasks.id` |
| `role` | `input/mask/output` |
| `sort_order` | stable display order |
| `storage_provider` | `cos` or explicit provider |
| `storage_key` | object key |
| `storage_url` | display URL |
| `mime_type` | image MIME |
| `width/height/size_bytes` | metadata |
| `related_file_id` | mask target, nullable |
| `revised_prompt` | provider output metadata |
| `created_at/updated_at` | lifecycle |

Do not reintroduce a global `ai_image_assets` table for task inputs/outputs. A generated image saved to Canvas asset library belongs to `canvas_assets`; the task output itself belongs to `ai_image_files`.

## API contract

External routes stay stable.

### Admin transport

```text
GET    /api/admin/v1/ai-images/page-init
GET    /api/admin/v1/ai-images
GET    /api/admin/v1/ai-images/:id
POST   /api/admin/v1/ai-images
PATCH  /api/admin/v1/ai-images/:id/favorite
DELETE /api/admin/v1/ai-images/:id
```

Admin transport always uses `platform=admin`.

### Canvas transport

```text
GET    /api/canvas/v1/ai/images
GET    /api/canvas/v1/ai/images/:id
POST   /api/canvas/v1/ai/images/generations
POST   /api/canvas/v1/ai/images/edits
DELETE /api/canvas/v1/ai/images/:id
```

Canvas transport always uses `platform=canvas`.

Canvas generation requests still submit only:

```text
agent_id
prompt
n
quality
size
uploaded reference files for edits
```

They must not accept browser-provided provider/model/api_key/base_url overrides.

## AI run monitor

`ai_runs` remains the unified provider-attempt monitor.

Use one source type:

```text
ai_image_task
```

The platform is already represented by:

```text
ai_runs.platform
```

This avoids redundant source types:

```text
admin_ai_image_task
canvas_image_task
```

Those two source types only exist because the current split invented two task tables.

## Frontend behavior

### Admin Vue

Admin Vue may keep the current image workbench route for now, but it must call the shared Admin image transport and consume `ai_image_tasks` DTOs. It must not imply a separate Admin image product table.

If product direction later says Admin image workbench is not needed, remove that menu/page in a separate UI-retirement slice. Do not mix that decision into the data-model convergence.

### Canvas Next

Canvas image generation history must come from backend:

```text
GET /api/canvas/v1/ai/images
```

Retire browser-local generation logs as business truth:

```text
localforage image_generation_logs
logStore.setItem(...)
readStoredLogs()
```

Allowed browser state after convergence:

```text
current in-flight UI state
draft prompt text
temporary selected references before submission
theme/config/session state
```

Not allowed:

```text
completed generation history as localforage truth
generated output records only visible on the same browser
silent fallback from backend list failure to browser history
```

## Migration strategy

The product is not online, so prefer a simple destructive convergence instead of compatibility code.

Target migration:

1. Ensure `ai_image_tasks` has `platform`.
2. Ensure `ai_image_files` exists.
3. If local rows need preservation, copy from the current split tables into the unified tables by fixed platform:
   - `admin_ai_image_tasks` -> `ai_image_tasks.platform='admin'`
   - `canvas_image_tasks` -> `ai_image_tasks.platform='canvas'`
4. Copy task files into `ai_image_files`.
5. Update `ai_runs.source_type` from:
   - `admin_ai_image_task` -> `ai_image_task`
   - `canvas_image_task` -> `ai_image_task`
6. Drop split tables:
   - `admin_ai_image_files`
   - `admin_ai_image_tasks`
   - `canvas_image_files`
   - `canvas_image_tasks`
7. Keep old `ai_image_assets` / `ai_image_task_assets` retired.

No long-lived code should support both table shapes.

## Rejected approaches

### Keep `internal/module/canvas/image`

Rejected. It makes Canvas the owner of an AI runtime capability and diverges from chat/video.

### Keep four tables but move files under `ai/image`

Rejected. It fixes directory cosmetics while preserving the wrong data model.

### Keep Canvas localforage history as fallback

Rejected. A fallback would hide backend contract failures. If backend history fails, the UI should show an explicit error or empty backend state, not stale local records.

## Tests and guards

Backend guards:

```text
no internal/module/canvas/image production package
no internal/module/ai/adminimage production package
internal/module/ai/image/transport/admin exists
internal/module/ai/image/transport/canvas exists
Canvas routes register through ai/image transport
```

Backend service tests:

```text
Admin create writes ai_image_tasks.platform=admin
Canvas create writes ai_image_tasks.platform=canvas
Admin list filters platform=admin
Canvas list filters platform=canvas
Admin favorite cannot mutate a Canvas task
Canvas detail cannot read an Admin task
worker success writes ai_image_files(role=output)
edit reference uploads write ai_image_files(role=input)
mask writes ai_image_files(role=mask)
ai_runs source_type=ai_image_task and platform matches task platform
```

Frontend Canvas tests:

```text
image page fetches GET /api/canvas/v1/ai/images for history
image page does not import localforage for generation logs
image service does not send provider/model/api_key/base_url overrides
delete history calls DELETE /api/canvas/v1/ai/images/:id
```

Frontend Admin tests:

```text
Admin image API keeps /api/admin/v1/ai-images
Admin image create sends task-owned input_files/mask_file
Admin image API does not call /ai-images/assets
```

Docs/knowledge guards:

```text
route inventory has /api/admin/v1/ai-images and /api/canvas/v1/ai/images
capability manifest lists ai/image as the image-generation owner
DB ownership map maps ai_image_tasks and ai_image_files to ai/image
current-status does not claim admin_ai_image_* or canvas_image_* are active tables
```

## Acceptance

This design is accepted only when:

1. There is one image capability: `internal/module/ai/image`.
2. There are two platform transports: `transport/admin` and `transport/canvas`.
3. Active image task state uses `ai_image_tasks` and `ai_image_files`.
4. `internal/module/canvas/image` is removed.
5. `internal/module/ai/adminimage` is removed.
6. Canvas generation history is backend-owned, not browser-cache-owned.
7. External Admin and Canvas image API routes remain stable.
8. No silent fallback hides missing backend image history.
9. Targeted backend/frontend tests and root governance checks pass.
