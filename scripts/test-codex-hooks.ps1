$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $root = & git -C $scriptDir rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot resolve repo root: $root"
    }
    return (($root | Select-Object -First 1).ToString()).Trim()
}

function Invoke-HookScript {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$RelativePath,
        [Parameter(Mandatory=$true)][hashtable]$InputObject
    )

    $scriptPath = Join-Path $RepoRoot $RelativePath
    $inputJson = $InputObject | ConvertTo-Json -Depth 20 -Compress
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'powershell'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Write($inputJson)
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "Hook script failed with exit code $($process.ExitCode): $errorOutput"
    }

    return $output.Trim()
}

function Invoke-HookCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][hashtable]$InputObject
    )

    $inputJson = $InputObject | ConvertTo-Json -Depth 20 -Compress
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = "/d /s /c `"$Command`""
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Write($inputJson)
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "Hook command failed with exit code $($process.ExitCode): $errorOutput Command: $Command"
    }

    return $output.Trim()
}

function Get-HookCommand {
    param(
        [Parameter(Mandatory=$true)]$HooksConfig,
        [Parameter(Mandatory=$true)][string]$EventName
    )

    $eventConfig = $HooksConfig.hooks.$EventName
    if ($null -eq $eventConfig -or $eventConfig.Count -lt 1) {
        throw "Expected hooks.json to define event '$EventName'."
    }

    $command = $eventConfig[0].hooks[0].command
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw "Expected hooks.json event '$EventName' to define a command."
    }
    return $command
}

function Convert-JsonOutput {
    param([string]$Output)
    if ([string]::IsNullOrWhiteSpace($Output)) {
        throw 'Expected JSON output, got empty output.'
    }
    return $Output | ConvertFrom-Json
}

function Assert-Contains {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][string]$Expected
    )
    if ($Text -notlike "*$Expected*") {
        throw "Expected text to contain '$Expected'. Actual: $Text"
    }
}

function Assert-Equals {
    param(
        [Parameter(Mandatory=$true)]$Actual,
        [Parameter(Mandatory=$true)]$Expected,
        [Parameter(Mandatory=$true)][string]$Message
    )
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

$repoRoot = Resolve-RepoRoot
$hooksConfig = Get-Content (Join-Path $repoRoot '.codex/hooks.json') -Raw | ConvertFrom-Json

$sessionOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/session_start.ps1' -InputObject @{
    hook_event_name = 'SessionStart'
    source = 'startup'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$sessionJson = Convert-JsonOutput $sessionOutput
Assert-Equals $sessionJson.hookSpecificOutput.hookEventName 'SessionStart' 'SessionStart event mismatch.'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'Superpowers'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'TDD'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'agents/'

$promptOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/user_prompt_submit.ps1' -InputObject @{
    hook_event_name = 'UserPromptSubmit'
    prompt = '继续实现这个功能'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$promptJson = Convert-JsonOutput $promptOutput
Assert-Equals $promptJson.hookSpecificOutput.hookEventName 'UserPromptSubmit' 'UserPromptSubmit event mismatch.'
Assert-Contains $promptJson.hookSpecificOutput.additionalContext 'brainstorming'
Assert-Contains $promptJson.hookSpecificOutput.additionalContext 'TDD'

$preOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/pre_tool_use.ps1' -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git reset --hard HEAD'
    }
}
$preJson = Convert-JsonOutput $preOutput
Assert-Equals $preJson.hookSpecificOutput.hookEventName 'PreToolUse' 'PreToolUse event mismatch.'
Assert-Equals $preJson.hookSpecificOutput.permissionDecision 'deny' 'Dangerous command should be denied.'

$postOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/post_tool_use.ps1' -InputObject @{
    hook_event_name = 'PostToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git diff -- docs/architecture/02-agent-framework.md'
    }
    tool_response = @{
        exit_code = 0
    }
}
$postJson = Convert-JsonOutput $postOutput
Assert-Equals $postJson.hookSpecificOutput.hookEventName 'PostToolUse' 'PostToolUse event mismatch.'
Assert-Contains $postJson.hookSpecificOutput.additionalContext 'check-agent-governance.ps1'

$stopOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/stop_review.ps1' -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = '已完成，修好了。'
}
$stopJson = Convert-JsonOutput $stopOutput
Assert-Equals $stopJson.decision 'block' 'Unverified completion should continue the turn.'
Assert-Contains $stopJson.reason '验证'

$stopBareVerifyOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/stop_review.ps1' -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = '已完成，修好了。验证'
}
$stopBareVerifyJson = Convert-JsonOutput $stopBareVerifyOutput
Assert-Equals $stopBareVerifyJson.decision 'block' 'Bare 验证 should not count as evidence.'

$stopBarePassOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/stop_review.ps1' -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = '已完成，修好了。通过'
}
$stopBarePassJson = Convert-JsonOutput $stopBarePassOutput
Assert-Equals $stopBarePassJson.decision 'block' 'Bare 通过 should not count as evidence.'

$stopBareEnglishPassOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'Stop') -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = 'done, passed'
}
$stopBareEnglishPassJson = Convert-JsonOutput $stopBareEnglishPassOutput
Assert-Equals $stopBareEnglishPassJson.decision 'block' 'Bare passed should not count as evidence.'

$sessionCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'SessionStart') -InputObject @{
    hook_event_name = 'SessionStart'
    source = 'startup'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$sessionCommandJson = Convert-JsonOutput $sessionCommandOutput
Assert-Equals $sessionCommandJson.hookSpecificOutput.hookEventName 'SessionStart' 'hooks.json SessionStart event mismatch.'
Assert-Contains $sessionCommandJson.hookSpecificOutput.additionalContext 'Superpowers'

$promptCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'UserPromptSubmit') -InputObject @{
    hook_event_name = 'UserPromptSubmit'
    prompt = 'hooks 治理文档'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$promptCommandJson = Convert-JsonOutput $promptCommandOutput
Assert-Equals $promptCommandJson.hookSpecificOutput.hookEventName 'UserPromptSubmit' 'hooks.json UserPromptSubmit event mismatch.'
Assert-Contains $promptCommandJson.hookSpecificOutput.additionalContext 'Governance reminder'

$preCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'PreToolUse') -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git reset --hard HEAD'
    }
}
$preCommandJson = Convert-JsonOutput $preCommandOutput
Assert-Equals $preCommandJson.hookSpecificOutput.hookEventName 'PreToolUse' 'hooks.json PreToolUse event mismatch.'
Assert-Equals $preCommandJson.hookSpecificOutput.permissionDecision 'deny' 'hooks.json PreToolUse command should deny dangerous command.'

$cleanCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'PreToolUse') -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git clean -fd'
    }
}
$cleanCommandJson = Convert-JsonOutput $cleanCommandOutput
Assert-Equals $cleanCommandJson.hookSpecificOutput.permissionDecision 'deny' 'git clean -fd should be denied.'

$removeCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'PreToolUse') -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'Remove-Item E:\admin_go -Recurse -Force'
    }
}
$removeCommandJson = Convert-JsonOutput $removeCommandOutput
Assert-Equals $removeCommandJson.hookSpecificOutput.permissionDecision 'deny' 'Remove-Item recursive workspace deletion should be denied.'

$removeDotCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'PreToolUse') -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'Remove-Item . -Recurse -Force'
    }
}
$removeDotCommandJson = Convert-JsonOutput $removeDotCommandOutput
Assert-Equals $removeDotCommandJson.hookSpecificOutput.permissionDecision 'deny' 'Remove-Item recursive current-directory deletion should be denied.'

$postCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'PostToolUse') -InputObject @{
    hook_event_name = 'PostToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git diff -- docs/architecture/02-agent-framework.md'
    }
    tool_response = @{
        exit_code = 0
    }
}
$postCommandJson = Convert-JsonOutput $postCommandOutput
Assert-Equals $postCommandJson.hookSpecificOutput.hookEventName 'PostToolUse' 'hooks.json PostToolUse event mismatch.'
Assert-Contains $postCommandJson.hookSpecificOutput.additionalContext 'check-agent-governance.ps1'

$stopCommandOutput = Invoke-HookCommand -Command (Get-HookCommand -HooksConfig $hooksConfig -EventName 'Stop') -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = '已完成，修好了。'
}
$stopCommandJson = Convert-JsonOutput $stopCommandOutput
Assert-Equals $stopCommandJson.decision 'block' 'hooks.json Stop command should block unverified completion.'
Assert-Contains $stopCommandJson.reason '验证'

Write-Host 'PASS: Codex hook behavior tests passed.'
