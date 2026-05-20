$ErrorActionPreference = 'Stop'
$script:AdminGoHookRawInput = @($input) -join "`n"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$prompt = Get-StringValue $inputObject.prompt

$implementationWord = [string]([char]0x5B9E) + [string]([char]0x73B0)
$continueWord = [string]([char]0x7EE7) + [string]([char]0x7EED)
$fixWord = [string]([char]0x4FEE)
$planWord = [string]([char]0x8BA1) + [string]([char]0x5212)
$implementationPattern = "$implementationWord|$continueWord|$fixWord|$planWord|fix|implement|continue|plan|refactor"
$governancePattern = '文档|agent|hooks|hook|Superpowers|TDD|治理|AGENTS\.md|codex'

if ($prompt -match $governancePattern) {
    $context = @'
Governance reminder:
- Keep governance docs in the root repo.
- Codex hooks are conversation-time governance; Git pre-push remains the push-time gate.
- For docs-only governance changes, run git diff --check and scripts/check-agent-governance.ps1 before claiming completion.
'@
    Write-HookContext -EventName 'UserPromptSubmit' -Context $context
    exit 0
}

if ($prompt -match $implementationPattern) {
    $context = @'
Project workflow reminder:
- If this request creates or changes behavior, use Superpowers brainstorming before implementation unless an approved spec already exists.
- Before feature, bugfix, or refactor implementation, use TDD: write the failing test, verify RED, implement minimal code, verify GREEN, then refactor.
- Start from current repo truth: current-status, contracts, architecture docs, git diff/status, targeted tests, logs, and official docs for tool-specific behavior.
'@
    Write-HookContext -EventName 'UserPromptSubmit' -Context $context
    exit 0
}

Write-HookNoop
