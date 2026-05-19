$ErrorActionPreference = 'Stop'
$script:AdminGoHookRawInput = @($input) -join "`n"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$toolName = Get-StringValue $inputObject.tool_name
$command = Get-StringValue $inputObject.tool_input.command

if ($toolName -ne 'Bash' -and $toolName -ne 'shell_command') {
    exit 0
}

$dangerousPatterns = @(
    'git\s+reset\s+--hard\b',
    'git\s+clean\b[^\r\n]*(?:-fdx|-xdf|-fxd|-dfx|-fd|-df)\b',
    'git\s+push\b[^\r\n]*(?:--force|-f)\b',
    'rm\s+-rf\b[^\r\n]*(?:E:[\\/]+admin_go|admin_back_go|admin_front_ts|\.git)'
)

foreach ($pattern in $dangerousPatterns) {
    if ($command -match $pattern) {
        Write-PreToolDeny -Reason "Blocked by admin_go Codex hook: low-dispute destructive command matched '$pattern'. Ask the user for an explicit narrow confirmation or use a reversible command."
        exit 0
    }
}

# "." / "./" / ".\" is repo-wide when Codex runs from E:\admin_go, so treat it like a protected target for recursive deletion.
$removeItemCurrentDirPattern = '(?:^|\s)(?:"\.(?:[\\/])?"|''\.(?:[\\/])?''|\.(?:[\\/])?)(?=\s|$)'
$removeItemTargetPattern = "E:[\\/]+admin_go|admin_back_go|admin_front_ts|\.git|$removeItemCurrentDirPattern"
if ($command -match 'Remove-Item\b' -and $command -match '-Recurse\b' -and $command -match $removeItemTargetPattern) {
    Write-PreToolDeny -Reason 'Blocked by admin_go Codex hook: Remove-Item recursive deletion against a protected workspace or current-directory target. Ask the user for an explicit narrow confirmation or use a reversible command.'
    exit 0
}
