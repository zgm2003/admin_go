# Canvas AI Request Contract Design

Date: 2026-06-07

## Problem

Canvas frontend already selects backend-managed agents from `/api/canvas/v1/settings`, but backend chat/video transports still accepted a client `model` field. That is bad taste: the state exists only because the boundary is unclear.

If `agent_id` owns provider/model dispatch, accepting `model` is not compatibility; it is silent override debt.

## Goal

Make Canvas AI generation request semantics explicit:

```text
Canvas browser submits agent_id + user content + generation params.
Backend selected agent owns provider/model/api key/base_url.
Client fields model/provider/api_key/base_url are rejected.
```

## Non-goals

```text
Do not change provider runtime selection.
Do not change ai_agents schema.
Do not close Canvas RBAC text permission drift.
Do not decide /asset-library vs /assets route ownership.
Do not claim live route smoke from source tests.
```

## Data rules

- Chat request body is JSON `agent_id` + `message`.
- Image generation body is JSON `agent_id` + `prompt` + image params.
- Image edit body is FormData `agent_id` + `prompt` + image files + image params.
- Video creation accepts JSON or active-client FormData `agent_id` + `prompt` + video params.
- Forbidden client fields are `model`, `provider`, `api_key`, and `base_url`.
- Reject forbidden fields before service invocation; do not ignore them.

## Verification target

```text
backend transport tests prove rejection and empty service ModelID.
canvas frontend tests prove clients do not send model.
contract docs and knowledge artifact state the same rule.
runtime fact checker guards request structs, handler forwarding, artifact links, and known-issue closure.
```

