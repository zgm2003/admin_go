$ErrorActionPreference = 'Stop'

function Read-HookInput {
    $raw = ''
    $captured = Get-Variable -Name AdminGoHookRawInput -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $captured) {
        $raw = Get-StringValue $captured.Value
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $raw = [Console]::In.ReadToEnd()
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }
    try {
        return $raw | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{}
    }
}

function Write-HookContext {
    param(
        [Parameter(Mandatory=$true)][string]$EventName,
        [Parameter(Mandatory=$true)][string]$Context
    )

    @{
        hookSpecificOutput = @{
            hookEventName = $EventName
            additionalContext = $Context
        }
    } | ConvertTo-Json -Depth 20 -Compress
}

function Write-PreToolDeny {
    param([Parameter(Mandatory=$true)][string]$Reason)

    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Depth 20 -Compress
}

function Write-StopBlock {
    param([Parameter(Mandatory=$true)][string]$Reason)

    @{
        decision = 'block'
        reason = $Reason
    } | ConvertTo-Json -Depth 20 -Compress
}

function Get-StringValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    return $Value.ToString()
}
