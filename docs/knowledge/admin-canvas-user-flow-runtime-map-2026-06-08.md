# Admin Canvas User Flow Runtime Map

Date: 2026-06-08

This document maps the current Admin Vue and Canvas Next user flows end-to-end. It is a runtime handoff map, not a UI spec and not a replacement for smoke tests.

## Admin flow

| Step | Browser/runtime action | Backend owner | State written/read | Guardrail |
| --- | --- | --- | --- | --- |
| Login config | Admin login reads admin auth config/captcha rules | `auth/transport/admin`, `auth_platform` | `auth_platforms`, captcha/session Redis | Do not invent browser-only login policy |
| Login submit | Admin calls `/api/admin/v1/auth/login` | `auth` | `users`, `login_logs`, session Redis | Keep platform = admin |
| Bootstrap | `UsersApi.me()` calls `GET /api/admin/v1/users/me` | `user/transport/admin` + `permission` | `permissions`, `roles`, `role_permissions` | Do not restore `users/init` |
| Route mount | `setupDynamicRoutes()` uses backend `router` + local view registry | Admin Vue adapter | Pinia user store | Missing local view is explicit frontend error, not backend fallback |
| Button display | Components call `userStore.can(code)` | permission codes from backend | `buttonCodes` | Do not use page path as button permission |
| API calls | Page APIs call `/api/admin/v1/*` | capability transport/admin | capability tables | Use frontend-page-runtime-map to find owner |
| Realtime | WebSocket subscribes to notification/AI events | `realtime`, `notification`, `ai/chat` | Redis pub/sub + notifications | AI cancel remains REST |
| Logout | Admin auth logout/session cleanup | `auth` | session Redis | Do not silently keep stale browser state after failed revoke unless contract says so |

## Canvas flow

| Step | Browser/runtime action | Backend owner | State written/read | Guardrail |
| --- | --- | --- | --- | --- |
| Login config | `/api/canvas/v1/auth/login-config` controls login methods | `auth/transport/canvas`, `auth_platform` | `auth_platforms` | No standalone registration page; allow_register is backend config |
| Verification login | email/phone send-code then login | `auth`, `mail`/`sms` verify-code owner | Redis verify-code namespace, mail/sms config tables | TTL comes from mail/sms configs, not hidden env fallback |
| Password login | submit triggers captcha only at login action | `auth/canvas` | captcha/session Redis | Do not show independent captcha-first branch |
| Bootstrap | `(user)` shell calls `GET /api/canvas/v1/users/me` | `user/transport/canvas` + `permission` | `permissions`, `roles`, `role_permissions` | 401 redirects login; 403 shows no-permission page |
| Settings | `/api/canvas/v1/settings` loads enabled agents/scenes | `canvas`, `ai/agent` | `ai_agents`, `ai_providers`, `ai_provider_models` | Frontend sends `agent_id`; provider/model stays backend-owned |
| Prompt browsing | `/api/canvas/v1/prompts` | `ai/prompt/transport/canvas` | `ai_prompts` | Legacy `canvas_prompts` is retired |
| Asset library | `/api/canvas/v1/assets` current-user assets | `ai/asset/transport/canvas` | `ai_assets.user_id` | No `/asset-library`, no public `user_id=0` library |
| Image generation | `/api/canvas/v1/ai/images*` | `ai/image` | `ai_image_tasks`, `ai_image_files` | Free-generation; no balance debit |
| Video generation | `/api/canvas/v1/ai/videos*` | `ai/video` | `canvas_video_tasks`, `ai_runs` | run binding lives on `canvas_video_tasks.run_id` |
| Text/chat generation | `/api/canvas/v1/ai/chat` | `ai/chat` | `ai_conversations`, `ai_messages`, `ai_runs` | Reject client `model/provider/api_key/base_url` |
| Profile | `GET/PUT /api/canvas/v1/profile` | `profile/transport/canvas` | `users`, auth identities | Profile does not own users/me bootstrap |
| Logout | `useUserStore.logout()` calls backend revoke before local cleanup | `auth/transport/canvas` | session Redis/browser store | Backend failure preserves browser session |

## Flow invariants

```text
Admin and Canvas both bootstrap through /users/me DTO: user_id, username, avatar, role_name, permissions, router, buttonCodes.
Canvas PAGE rows: canvas_page, canvas_image_page, canvas_video_page, canvas_prompts_page, canvas_assets_page (/assets), canvas_profile_page.
Canvas active BUTTON rows: canvas_access, canvas_prompt_read, canvas_asset_read, canvas_ai_image_generate, canvas_ai_video_generate.
canvas_ai_text_generate is a soft-deleted orphan, not an active code.
```
