$ErrorActionPreference = 'Stop'
$script:AdminGoHookRawInput = @($input) -join "`n"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

[void](Read-HookInput)

$context = @'
admin_go Codex cold-start context:
- Treat E:\admin_go as the root governance repo; backend and frontend runtime repos are admin_back_go and admin_front_ts.
- Read AGENTS.md, docs/status/current-status.md, docs/architecture/02-agent-framework.md, docs/architecture/05-development-quality-rules.md, and docs/architecture/08-codex-hooks.md before editing.
- Default to Superpowers for requirement understanding, spec, plan, and TDD.
- Pick exactly one project agent role from agents/; do not act as an all-in-one agent.
- Codex hooks are conversation-time governance only. Git pre-push, tests, smoke, and runtime evidence are still required when relevant.
'@

Write-HookContext -EventName 'SessionStart' -Context $context
