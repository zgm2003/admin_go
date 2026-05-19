$ErrorActionPreference = 'Stop'
$script:AdminGoHookRawInput = @($input) -join "`n"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$command = Get-StringValue $inputObject.tool_input.command
$exitCode = Get-StringValue $inputObject.tool_response.exit_code

$governancePattern = 'AGENTS\.md|agents/|agents\\|docs/architecture/|docs\\architecture\\|docs/testing/|docs\\testing\\|scripts/check-agent-governance\.ps1|scripts/install-git-hooks\.ps1|\.githooks/|\.githooks\\|\.codex/|\.codex\\'

if ($command -match $governancePattern) {
    $context = @'
Governance file interaction detected:
- Before claiming completion, run git diff --check.
- Run powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working.
- If .codex/hooks.json or .codex/hooks/*.ps1 changed, tell the user to review/trust hooks with /hooks in Codex CLI.
'@
    Write-HookContext -EventName 'PostToolUse' -Context $context
    exit 0
}

if ($exitCode -ne '' -and $exitCode -ne '0') {
    $context = @'
The last tool command failed. Return to the earliest uncertain evidence, summarize the decisive error line, and avoid broadening the search blindly.
'@
    Write-HookContext -EventName 'PostToolUse' -Context $context
    exit 0
}
