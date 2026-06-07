# Canvas AI Request Contract Review

Date: 2026-06-07

Scope: active Canvas text/image/video generation request bodies and the backend guard that prevents client-side provider/model override.

This is source-and-test evidence, not a served-route smoke report.

## Contract summary

| Surface | Active request shape | Backend owner |
| --- | --- | --- |
| chat | chat: JSON `agent_id` + `message` | `admin_back_go/internal/module/ai/chat/transport/canvas` |
| image generation | image: JSON `agent_id` + `prompt` + image generation params | `admin_back_go/internal/module/ai/image/transport/canvas` |
| image edit | image edit: FormData `agent_id` + `prompt` + `image` files + image params | `admin_back_go/internal/module/ai/image/transport/canvas` |
| video | video: JSON or FormData `agent_id` + `prompt` + video params | `admin_back_go/internal/module/ai/video/transport/canvas` |

forbidden request fields: `model`, `provider`, `api_key`, `base_url`

The selected `agent_id` owns provider/model dispatch. The browser must not submit provider identity, model identity, API keys, or base URL. Backend Canvas chat/video transports now reject those fields with `canvas.ai.request.model_override_forbidden`; they do not silently ignore them.

## Evidence

Frontend source/test evidence:

```text
canvas_front_next/src/services/api/image.ts sends chat { agent_id, message } and image { agent_id, prompt, ...params }.
canvas_front_next/src/services/api/image.test.ts asserts chat/image requests do not invent a model override.
canvas_front_next/src/services/api/video.ts sends video FormData with agent_id, prompt, duration_seconds, size, and resolution_name.
canvas_front_next/src/services/api/video.test.ts asserts video FormData has no model field.
```

Backend source/test evidence:

```text
admin_back_go/internal/module/ai/chat/transport/canvas/request.go contains no json:"model" request field.
admin_back_go/internal/module/ai/video/transport/canvas/request.go contains no json:"model" request field.
admin_back_go/internal/module/ai/internal/canvasrequest/json.go rejects model/provider/api_key/base_url before service invocation.
admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go covers JSON override rejection and verifies service input ModelID stays empty.
admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go covers JSON/form override rejection, active-client multipart binding, and verifies service input ModelID stays empty.
```

## Boundary

This closes the Canvas AI request model-field semantics gap only.

The separate asset-route ambiguity is closed by:

```text
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md
```
