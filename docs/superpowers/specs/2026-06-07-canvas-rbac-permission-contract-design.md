# Canvas RBAC Permission Contract Design

Date: 2026-06-07

## Problem

Canvas text generation has two similar-looking identifiers:

```text
canvas_text_generate      # ai_agents scene
canvas_ai_text_generate   # stale RBAC BUTTON code from earlier design
```

Conflating them is bad data design. `canvas_text_generate` selects backend-managed text agents. `canvas_ai_text_generate` is not required by the current UI, route metadata, seed contract, or live MySQL active permissions.

## Goal

Make the active Canvas RBAC contract explicit:

```text
Canvas PAGE access controls route/menu visibility.
Canvas BUTTON codes control only active frontend actions.
Text generation does not have a separate active BUTTON code in this slice.
canvas_ai_text_generate must stay out of canonical frontend permission types and active contract docs.
```

## Non-goals

```text
Do not add a new text-generation BUTTON permission.
Do not add PermissionCheck metadata to Canvas chat/text generation route.
Do not change /api/canvas/v1/ai/chat/completions.
Do not change ai_agents scenes_json canvas_text_generate.
Do not resolve /asset-library vs /assets route ambiguity.
```

## Evidence rules

- Frontend `CanvasPermissionCode` must not include `canvas_ai_text_generate`.
- Frontend tests must reject `canvas_ai_text_generate` in the canonical RBAC registry.
- Contract docs must list active Canvas BUTTON rows without `canvas_ai_text_generate`.
- Live MySQL may contain a historical `canvas_ai_text_generate` row only if it is a soft-deleted orphan: `parent_id=0`, `type=3`, `status=2`, `is_del=1`.
- The review artifact must record why this is a dead permission type, not a missing backend seed.

## Verification target

```text
canvas_front_next targeted RBAC test passes.
canvas_front_next typecheck passes.
root runtime fact checker with -LiveSchema verifies source/docs and live MySQL permission row state.
root governance gates pass.
```
