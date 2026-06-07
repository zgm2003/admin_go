# Codex Lifecycle Hooks

## Purpose

Codex lifecycle hooks are the conversation-time governance layer for `E:\admin_go`.

They help Codex remember project rules while a turn is running:

```text
SessionStart      -> load cold-start context
UserPromptSubmit  -> remind Superpowers/TDD/docs-first rules
PreToolUse        -> block low-dispute dangerous commands
PostToolUse       -> remind verification after governance changes
Stop              -> prevent unsupported completion claims
```

Hooks do not replace runtime evidence, smoke, tests, or Git pre-push governance.

## Source of truth

Official behavior reference:

- https://developers.openai.com/codex/hooks
- https://developers.openai.com/codex/config-reference#configtoml

Current repo-local hook files:

```text
.codex/hooks.json
.codex/hooks/*.ps1
.codex/hooks/lib/AdminGoHookCommon.ps1
scripts/test-codex-hooks.ps1
```

## Loading and trust

Project-local hooks load only when Codex trusts the project config layer.

After hook files change, open Codex CLI and run:

```text
/hooks
```

Review the loaded hook sources and trust the repo-local hooks if they match the checked-in files.

## Event policy

| Event | Policy |
| --- | --- |
| `SessionStart` | Add cold-start context for `AGENTS.md`, `current-status`, Superpowers, TDD, and project agent roles. |
| `UserPromptSubmit` | Add governance context for docs/agent/hooks prompts first; otherwise add Superpowers/TDD context when the user asks to change behavior, implement, fix, continue, refactor, or write a plan. |
| `PreToolUse` | Deny low-dispute destructive commands such as hard reset, force clean, broad recursive delete, deleting `.git`, and force push. Hooks cannot infer conversation-level intent; use a narrower reversible command or get explicit confirmation before retrying. |
| `PostToolUse` | Add verification reminders when governance files changed or a command failed. |
| `Stop` | Continue the turn when the final answer claims completion without verification evidence. |

## Hard limits

Hooks are engineering guardrails, not a security boundary.

```text
Do not rely on hooks to intercept every possible tool path.
Do not let hooks auto-edit files.
Do not let hooks auto-stage, auto-commit, auto-push, or auto-revert.
Do not treat hook pass as smoke or runtime verification.
```

## Verification

For hook script changes, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

If a task changes backend/frontend runtime, run the task-specific tests separately. Hook tests only prove hook behavior.
