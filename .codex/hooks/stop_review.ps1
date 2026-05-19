$ErrorActionPreference = 'Stop'
$script:AdminGoHookRawInput = @($input) -join "`n"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput

if ($inputObject.stop_hook_active -eq $true) {
    exit 0
}

$message = Get-StringValue $inputObject.last_assistant_message
if ([string]::IsNullOrWhiteSpace($message)) {
    exit 0
}

$completeWord = [string]([char]0x5B8C) + [string]([char]0x6210)
$fixedWord = [string]([char]0x4FEE) + [string]([char]0x597D)
$verifiedWord = [string]([char]0x9A8C) + [string]([char]0x8BC1)
$claimPattern = "$completeWord|$fixedWord|done|fixed|passed|complete"
$notVerifiedWord = [string]([char]0x672A) + $verifiedWord
$evidencePattern = "git diff --check|test-codex-hooks\.ps1|check-agent-governance\.ps1|go test|npm run|vue-tsc|smoke|PASS:|FAIL|exit 0|Exit code: 0|not verified|$notVerifiedWord"

if ($message -match $claimPattern -and $message -notmatch $evidencePattern) {
    Write-StopBlock -Reason '你刚才声称完成或通过，但最终回答里没有验证证据。请继续一轮：补充实际验证命令和结果；如果只是设计完成或尚未验证，请明确写“未验证”。'
    exit 0
}
